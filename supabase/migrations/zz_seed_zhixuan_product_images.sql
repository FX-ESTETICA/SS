-- 将演示商品图统一切到 zhixuan 正式媒体链路

WITH desired_products AS (
  SELECT *
  FROM (
    VALUES
      (
        '2026新款降维打击极客双肩包，防水防盗超大容量，程序员必备',
        'https://zhixuan-media-upload.499755740.workers.dev/objects/products/demo/backpack.jpg',
        299.00::numeric,
        10500,
        '智选官方旗舰店'
      ),
      (
        '意大利原装进口特级初榨橄榄油 500ml 凉拌煎炒佳品',
        'https://zhixuan-media-upload.499755740.workers.dev/objects/products/demo/olive-oil.jpg',
        158.00::numeric,
        3200,
        '罗马阳光直邮'
      ),
      (
        '超轻量全碳纤维折叠自行车，通勤代步神器，仅重8kg',
        'https://zhixuan-media-upload.499755740.workers.dev/objects/products/demo/bicycle.jpg',
        1999.00::numeric,
        856,
        '极速出行'
      ),
      (
        'AI架构师同款人体工学椅，护腰护颈，久坐不累',
        'https://zhixuan-media-upload.499755740.workers.dev/objects/products/demo/chair.jpg',
        899.00::numeric,
        5600,
        '智选家居'
      ),
      (
        '有机种植纯棉T恤，透气吸汗，夏季情侣款',
        'https://zhixuan-media-upload.499755740.workers.dev/objects/products/demo/tshirt.jpg',
        89.00::numeric,
        20100,
        '基础生活'
      ),
      (
        '降噪蓝牙耳机 Pro Max，沉浸式体验，续航48小时',
        'https://zhixuan-media-upload.499755740.workers.dev/objects/products/demo/headphones.jpg',
        499.00::numeric,
        12000,
        '数码狂人'
      )
  ) AS t(title, image_url, price, sales_count, shop_name)
),
updated_products AS (
  UPDATE products AS p
  SET image_url = d.image_url,
      price = d.price,
      sales_count = d.sales_count,
      shop_name = d.shop_name
  FROM desired_products AS d
  WHERE p.title = d.title
  RETURNING p.title
)
INSERT INTO products (title, image_url, price, sales_count, shop_name)
SELECT d.title, d.image_url, d.price, d.sales_count, d.shop_name
FROM desired_products AS d
WHERE NOT EXISTS (
  SELECT 1
  FROM products AS p
  WHERE p.title = d.title
);
