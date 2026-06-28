-- 将现有商品图正式链路标准化为 jpg 对象名与 image/jpeg 媒体类型

UPDATE products
SET image_url = CASE title
  WHEN '2026新款降维打击极客双肩包，防水防盗超大容量，程序员必备'
    THEN 'https://zhixuan-media-upload.499755740.workers.dev/objects/products/demo/backpack.jpg'
  WHEN '意大利原装进口特级初榨橄榄油 500ml 凉拌煎炒佳品'
    THEN 'https://zhixuan-media-upload.499755740.workers.dev/objects/products/demo/olive-oil.jpg'
  WHEN '超轻量全碳纤维折叠自行车，通勤代步神器，仅重8kg'
    THEN 'https://zhixuan-media-upload.499755740.workers.dev/objects/products/demo/bicycle.jpg'
  WHEN 'AI架构师同款人体工学椅，护腰护颈，久坐不累'
    THEN 'https://zhixuan-media-upload.499755740.workers.dev/objects/products/demo/chair.jpg'
  WHEN '有机种植纯棉T恤，透气吸汗，夏季情侣款'
    THEN 'https://zhixuan-media-upload.499755740.workers.dev/objects/products/demo/tshirt.jpg'
  WHEN '降噪蓝牙耳机 Pro Max，沉浸式体验，续航48小时'
    THEN 'https://zhixuan-media-upload.499755740.workers.dev/objects/products/demo/headphones.jpg'
  ELSE image_url
END
WHERE title IN (
  '2026新款降维打击极客双肩包，防水防盗超大容量，程序员必备',
  '意大利原装进口特级初榨橄榄油 500ml 凉拌煎炒佳品',
  '超轻量全碳纤维折叠自行车，通勤代步神器，仅重8kg',
  'AI架构师同款人体工学椅，护腰护颈，久坐不累',
  '有机种植纯棉T恤，透气吸汗，夏季情侣款',
  '降噪蓝牙耳机 Pro Max，沉浸式体验，续航48小时'
);
