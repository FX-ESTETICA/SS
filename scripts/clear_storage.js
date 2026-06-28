import { createClient } from '@supabase/supabase-js';

// 初始化 Supabase 客户端 (使用 Service Role Key 获得最高权限)
const supabaseUrl = 'https://izpolbeqdttjffbemvjr.supabase.co';
// 注意：这里由于我拿不到你的 Service Role Key，我们用客户端方式尝试删除，或者只是打印列表
// 在实际架构接管中，我会用 `supabase storage` 命令行工具来处理。
const supabaseKey = 'sb_publishable_MFLwIbZIgBmUAnP9rqcSVQ_zzTwpq3y'; // Anon Key 只能删自己上传的，如果你设置了 RLS

const supabase = createClient(supabaseUrl, supabaseKey);

async function emptyBucket() {
  console.log('开始扫描 media 存储桶...');
  const { data, error } = await supabase.storage.from('media').list();
  
  if (error) {
    console.error('扫描存储桶失败:', error);
    return;
  }

  if (!data || data.length === 0) {
    console.log('存储桶已经是空的了！');
    return;
  }

  console.log(`发现 ${data.length} 个文件，准备执行物理抹杀...`);
  
  const filesToRemove = data.map((x) => x.name);
  const { data: removeData, error: removeError } = await supabase
    .storage
    .from('media')
    .remove(filesToRemove);

  if (removeError) {
    console.error('删除文件失败 (可能是权限不足):', removeError);
  } else {
    console.log('物理文件抹杀成功！清理了以下文件:', removeData);
  }
}

emptyBucket();