-- 20260622_create_products_table.sql
-- 创建商城模块的商品表

CREATE TABLE IF NOT EXISTS products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  image_url TEXT NOT NULL,
  price DECIMAL(10, 2) NOT NULL,
  sales_count INTEGER DEFAULT 0 NOT NULL,
  shop_name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 配置 RLS (所有人可读，仅管理员可写)
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public products are viewable by everyone." ON products FOR SELECT USING (true);

-- 3. 插入一些淘宝风格的测试数据 (使用 Cloudflare R2 链接)
INSERT INTO products (title, image_url, price, sales_count, shop_name) VALUES
  ('2026新款降维打击极客双肩包，防水防盗超大容量，程序员必备', 'https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/shop_item_1.jpg', 299.00, 10500, '智选官方旗舰店'),
  ('意大利原装进口特级初榨橄榄油 500ml 凉拌煎炒佳品', 'https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/shop_item_2.jpg', 158.00, 3200, '罗马阳光直邮'),
  ('超轻量全碳纤维折叠自行车，通勤代步神器，仅重8kg', 'https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/shop_item_3.jpg', 1999.00, 856, '极速出行'),
  ('AI架构师同款人体工学椅，护腰护颈，久坐不累', 'https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/shop_item_4.jpg', 899.00, 5600, '智选家居'),
  ('有机种植纯棉T恤，透气吸汗，夏季情侣款', 'https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/shop_item_5.jpg', 89.00, 20100, '基础生活'),
  ('降噪蓝牙耳机 Pro Max，沉浸式体验，续航48小时', 'https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/shop_item_6.jpg', 499.00, 12000, '数码狂人');
