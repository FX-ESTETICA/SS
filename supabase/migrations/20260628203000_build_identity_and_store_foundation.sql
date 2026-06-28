-- 构建双身份、商户、门店与成员权限的长期底座

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.generate_prefixed_public_code(prefix TEXT)
RETURNS TEXT
LANGUAGE sql
AS $$
  SELECT prefix || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 10));
$$;

CREATE OR REPLACE FUNCTION public.set_row_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$;

CREATE TABLE IF NOT EXISTS public.user_profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  avatar_url TEXT,
  zodiac_sign TEXT DEFAULT '双子座' NOT NULL,
  shared_status TEXT DEFAULT '保持发光' NOT NULL,
  settings_json JSONB DEFAULT '{}'::jsonb NOT NULL,
  last_active_identity_id UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.user_identities (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  identity_kind TEXT NOT NULL,
  display_name TEXT NOT NULL,
  public_id TEXT UNIQUE,
  bio TEXT DEFAULT '' NOT NULL,
  is_enabled BOOLEAN DEFAULT true NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT uq_user_identity_kind UNIQUE (user_id, identity_kind),
  CONSTRAINT chk_user_identity_kind CHECK (identity_kind IN ('life', 'business'))
);

CREATE TABLE IF NOT EXISTS public.merchant_profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  identity_id UUID NOT NULL UNIQUE REFERENCES public.user_identities(id) ON DELETE CASCADE,
  merchant_display_name TEXT NOT NULL,
  merchant_status TEXT DEFAULT 'draft' NOT NULL,
  verification_status TEXT DEFAULT 'unverified' NOT NULL,
  onboarding_stage TEXT DEFAULT 'identity_created' NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT chk_merchant_status CHECK (merchant_status IN ('draft', 'active', 'suspended', 'archived')),
  CONSTRAINT chk_merchant_verification_status CHECK (verification_status IN ('unverified', 'pending', 'verified', 'rejected'))
);

CREATE TABLE IF NOT EXISTS public.stores (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  merchant_profile_id UUID NOT NULL REFERENCES public.merchant_profiles(id) ON DELETE CASCADE,
  owner_identity_id UUID NOT NULL REFERENCES public.user_identities(id) ON DELETE CASCADE,
  store_name TEXT NOT NULL,
  store_public_id TEXT UNIQUE,
  store_slug TEXT UNIQUE,
  store_status TEXT DEFAULT 'draft' NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT chk_store_status CHECK (store_status IN ('draft', 'active', 'suspended', 'archived'))
);

CREATE TABLE IF NOT EXISTS public.store_memberships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  identity_id UUID NOT NULL REFERENCES public.user_identities(id) ON DELETE CASCADE,
  membership_role TEXT NOT NULL,
  status TEXT DEFAULT 'active' NOT NULL,
  permissions_json JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT uq_store_membership UNIQUE (store_id, identity_id),
  CONSTRAINT chk_store_membership_role CHECK (membership_role IN ('owner', 'manager', 'staff')),
  CONSTRAINT chk_store_membership_status CHECK (status IN ('invited', 'active', 'suspended', 'revoked'))
);

DO $$
BEGIN
  ALTER TABLE public.user_profiles
    ADD CONSTRAINT fk_user_profiles_last_active_identity
    FOREIGN KEY (last_active_identity_id)
    REFERENCES public.user_identities(id)
    ON DELETE SET NULL;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_user_identities_user_id ON public.user_identities(user_id);
CREATE INDEX IF NOT EXISTS idx_user_identities_kind ON public.user_identities(user_id, identity_kind);
CREATE INDEX IF NOT EXISTS idx_merchant_profiles_identity_id ON public.merchant_profiles(identity_id);
CREATE INDEX IF NOT EXISTS idx_stores_owner_identity_id ON public.stores(owner_identity_id);
CREATE INDEX IF NOT EXISTS idx_stores_merchant_profile_id ON public.stores(merchant_profile_id);
CREATE INDEX IF NOT EXISTS idx_store_memberships_store_id ON public.store_memberships(store_id);
CREATE INDEX IF NOT EXISTS idx_store_memberships_identity_id ON public.store_memberships(identity_id);

CREATE OR REPLACE FUNCTION public.assign_identity_public_id()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.public_id IS NULL OR btrim(NEW.public_id) = '' THEN
    NEW.public_id := CASE
      WHEN NEW.identity_kind = 'life' THEN public.generate_prefixed_public_code('LX')
      WHEN NEW.identity_kind = 'business' THEN public.generate_prefixed_public_code('ZK')
      ELSE public.generate_prefixed_public_code('ID')
    END;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.assign_store_public_id()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.store_public_id IS NULL OR btrim(NEW.store_public_id) = '' THEN
    NEW.store_public_id := public.generate_prefixed_public_code('ST');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_user_profiles_set_updated_at ON public.user_profiles;
CREATE TRIGGER trg_user_profiles_set_updated_at
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_row_updated_at();

DROP TRIGGER IF EXISTS trg_user_identities_assign_public_id ON public.user_identities;
CREATE TRIGGER trg_user_identities_assign_public_id
  BEFORE INSERT ON public.user_identities
  FOR EACH ROW
  EXECUTE FUNCTION public.assign_identity_public_id();

DROP TRIGGER IF EXISTS trg_user_identities_set_updated_at ON public.user_identities;
CREATE TRIGGER trg_user_identities_set_updated_at
  BEFORE UPDATE ON public.user_identities
  FOR EACH ROW
  EXECUTE FUNCTION public.set_row_updated_at();

DROP TRIGGER IF EXISTS trg_merchant_profiles_set_updated_at ON public.merchant_profiles;
CREATE TRIGGER trg_merchant_profiles_set_updated_at
  BEFORE UPDATE ON public.merchant_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_row_updated_at();

DROP TRIGGER IF EXISTS trg_stores_assign_public_id ON public.stores;
CREATE TRIGGER trg_stores_assign_public_id
  BEFORE INSERT ON public.stores
  FOR EACH ROW
  EXECUTE FUNCTION public.assign_store_public_id();

DROP TRIGGER IF EXISTS trg_stores_set_updated_at ON public.stores;
CREATE TRIGGER trg_stores_set_updated_at
  BEFORE UPDATE ON public.stores
  FOR EACH ROW
  EXECUTE FUNCTION public.set_row_updated_at();

DROP TRIGGER IF EXISTS trg_store_memberships_set_updated_at ON public.store_memberships;
CREATE TRIGGER trg_store_memberships_set_updated_at
  BEFORE UPDATE ON public.store_memberships
  FOR EACH ROW
  EXECUTE FUNCTION public.set_row_updated_at();

CREATE OR REPLACE FUNCTION public.bootstrap_identity_graph(
  target_user_id UUID,
  target_email TEXT,
  raw_meta JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  base_name TEXT;
  avatar_url_text TEXT;
  life_identity_id UUID;
  business_identity_id UUID;
BEGIN
  base_name := COALESCE(
    NULLIF(raw_meta ->> 'display_name', ''),
    NULLIF(split_part(COALESCE(target_email, ''), '@', 1), ''),
    '生活用户'
  );
  avatar_url_text := NULLIF(raw_meta ->> 'avatar_url', '');

  INSERT INTO public.user_profiles (
    user_id,
    avatar_url
  ) VALUES (
    target_user_id,
    avatar_url_text
  )
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.user_identities (
    user_id,
    identity_kind,
    display_name,
    bio
  ) VALUES (
    target_user_id,
    'life',
    base_name,
    '生活身份'
  )
  ON CONFLICT (user_id, identity_kind) DO NOTHING;

  INSERT INTO public.user_identities (
    user_id,
    identity_kind,
    display_name,
    bio
  ) VALUES (
    target_user_id,
    'business',
    base_name || ' 智控',
    '智控身份'
  )
  ON CONFLICT (user_id, identity_kind) DO NOTHING;

  SELECT id
  INTO life_identity_id
  FROM public.user_identities
  WHERE user_id = target_user_id
    AND identity_kind = 'life'
  LIMIT 1;

  SELECT id
  INTO business_identity_id
  FROM public.user_identities
  WHERE user_id = target_user_id
    AND identity_kind = 'business'
  LIMIT 1;

  IF business_identity_id IS NOT NULL THEN
    INSERT INTO public.merchant_profiles (
      identity_id,
      merchant_display_name
    ) VALUES (
      business_identity_id,
      base_name
    )
    ON CONFLICT (identity_id) DO NOTHING;
  END IF;

  UPDATE public.user_profiles
  SET last_active_identity_id = COALESCE(last_active_identity_id, life_identity_id)
  WHERE user_id = target_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_auth_user_bootstrap()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.bootstrap_identity_graph(NEW.id, NEW.email, NEW.raw_user_meta_data);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auth_user_bootstrap_identity ON auth.users;
CREATE TRIGGER trg_auth_user_bootstrap_identity
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_auth_user_bootstrap();

DO $$
DECLARE
  auth_user RECORD;
BEGIN
  FOR auth_user IN
    SELECT id, email, raw_user_meta_data
    FROM auth.users
  LOOP
    PERFORM public.bootstrap_identity_graph(
      auth_user.id,
      auth_user.email,
      auth_user.raw_user_meta_data
    );
  END LOOP;
END $$;

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_identities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_memberships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can update their own profiles" ON public.user_profiles;
DROP POLICY IF EXISTS "Users can view their own identities" ON public.user_identities;
DROP POLICY IF EXISTS "Users can insert their own identities" ON public.user_identities;
DROP POLICY IF EXISTS "Users can update their own identities" ON public.user_identities;
DROP POLICY IF EXISTS "Users can delete their own identities" ON public.user_identities;
DROP POLICY IF EXISTS "Users can view their own merchant profiles" ON public.merchant_profiles;
DROP POLICY IF EXISTS "Users can insert their own merchant profiles" ON public.merchant_profiles;
DROP POLICY IF EXISTS "Users can update their own merchant profiles" ON public.merchant_profiles;
DROP POLICY IF EXISTS "Authenticated users can view stores" ON public.stores;
DROP POLICY IF EXISTS "Owners can insert stores" ON public.stores;
DROP POLICY IF EXISTS "Owners can update stores" ON public.stores;
DROP POLICY IF EXISTS "Owners can delete stores" ON public.stores;
DROP POLICY IF EXISTS "Users can view relevant memberships" ON public.store_memberships;
DROP POLICY IF EXISTS "Owners can manage memberships" ON public.store_memberships;

CREATE POLICY "Users can view their own profiles"
  ON public.user_profiles FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own profiles"
  ON public.user_profiles FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own profiles"
  ON public.user_profiles FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can view their own identities"
  ON public.user_identities FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert their own identities"
  ON public.user_identities FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own identities"
  ON public.user_identities FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete their own identities"
  ON public.user_identities FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can view their own merchant profiles"
  ON public.merchant_profiles FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = merchant_profiles.identity_id
        AND user_identities.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert their own merchant profiles"
  ON public.merchant_profiles FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = merchant_profiles.identity_id
        AND user_identities.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own merchant profiles"
  ON public.merchant_profiles FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = merchant_profiles.identity_id
        AND user_identities.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = merchant_profiles.identity_id
        AND user_identities.user_id = auth.uid()
    )
  );

CREATE POLICY "Authenticated users can view stores"
  ON public.stores FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Owners can insert stores"
  ON public.stores FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = stores.owner_identity_id
        AND user_identities.user_id = auth.uid()
    )
  );

CREATE POLICY "Owners can update stores"
  ON public.stores FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = stores.owner_identity_id
        AND user_identities.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = stores.owner_identity_id
        AND user_identities.user_id = auth.uid()
    )
  );

CREATE POLICY "Owners can delete stores"
  ON public.stores FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = stores.owner_identity_id
        AND user_identities.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view relevant memberships"
  ON public.store_memberships FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = store_memberships.identity_id
        AND user_identities.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1
      FROM public.stores
      JOIN public.user_identities
        ON user_identities.id = stores.owner_identity_id
      WHERE stores.id = store_memberships.store_id
        AND user_identities.user_id = auth.uid()
    )
  );

CREATE POLICY "Owners can manage memberships"
  ON public.store_memberships FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.stores
      JOIN public.user_identities
        ON user_identities.id = stores.owner_identity_id
      WHERE stores.id = store_memberships.store_id
        AND user_identities.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.stores
      JOIN public.user_identities
        ON user_identities.id = stores.owner_identity_id
      WHERE stores.id = store_memberships.store_id
        AND user_identities.user_id = auth.uid()
    )
  );

ALTER TABLE public.videos
  ADD COLUMN IF NOT EXISTS author_identity_id UUID REFERENCES public.user_identities(id) ON DELETE SET NULL;

ALTER TABLE public.media_assets
  ADD COLUMN IF NOT EXISTS owner_identity_id UUID REFERENCES public.user_identities(id) ON DELETE SET NULL;

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS merchant_identity_id UUID REFERENCES public.user_identities(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores(id) ON DELETE SET NULL;

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS sender_identity_id UUID REFERENCES public.user_identities(id) ON DELETE SET NULL;

UPDATE public.videos
SET author_identity_id = identities.id
FROM public.user_identities AS identities
WHERE videos.author_id = identities.user_id
  AND identities.identity_kind = 'life'
  AND videos.author_identity_id IS NULL;

UPDATE public.media_assets
SET owner_identity_id = identities.id
FROM public.user_identities AS identities
WHERE media_assets.owner_id = identities.user_id
  AND identities.identity_kind = 'life'
  AND media_assets.owner_identity_id IS NULL;

UPDATE public.messages
SET sender_identity_id = identities.id
FROM public.user_identities AS identities
WHERE messages.sender_id = identities.user_id::text
  AND identities.identity_kind = 'life'
  AND messages.sender_identity_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_videos_author_identity_id ON public.videos(author_identity_id);
CREATE INDEX IF NOT EXISTS idx_media_assets_owner_identity_id ON public.media_assets(owner_identity_id);
CREATE INDEX IF NOT EXISTS idx_products_merchant_identity_id ON public.products(merchant_identity_id);
CREATE INDEX IF NOT EXISTS idx_products_store_id ON public.products(store_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_identity_id ON public.messages(sender_identity_id);

DROP POLICY IF EXISTS "Authenticated users can insert their own videos" ON public.videos;
DROP POLICY IF EXISTS "Users can update their own videos" ON public.videos;
DROP POLICY IF EXISTS "Users can delete their own videos" ON public.videos;

CREATE POLICY "Authenticated users can insert their own videos"
  ON public.videos FOR INSERT
  TO authenticated
  WITH CHECK (
    author_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = videos.author_identity_id
        AND user_identities.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own videos"
  ON public.videos FOR UPDATE
  TO authenticated
  USING (
    author_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = videos.author_identity_id
        AND user_identities.user_id = auth.uid()
    )
  )
  WITH CHECK (
    author_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = videos.author_identity_id
        AND user_identities.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete their own videos"
  ON public.videos FOR DELETE
  TO authenticated
  USING (
    author_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = videos.author_identity_id
        AND user_identities.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can insert their own media assets" ON public.media_assets;
DROP POLICY IF EXISTS "Users can update their own media assets" ON public.media_assets;
DROP POLICY IF EXISTS "Users can delete their own media assets" ON public.media_assets;

CREATE POLICY "Users can insert their own media assets"
  ON public.media_assets FOR INSERT
  TO authenticated
  WITH CHECK (
    owner_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = media_assets.owner_identity_id
        AND user_identities.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own media assets"
  ON public.media_assets FOR UPDATE
  TO authenticated
  USING (
    owner_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = media_assets.owner_identity_id
        AND user_identities.user_id = auth.uid()
    )
  )
  WITH CHECK (
    owner_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = media_assets.owner_identity_id
        AND user_identities.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete their own media assets"
  ON public.media_assets FOR DELETE
  TO authenticated
  USING (
    owner_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.user_identities
      WHERE user_identities.id = media_assets.owner_identity_id
        AND user_identities.user_id = auth.uid()
    )
  );
