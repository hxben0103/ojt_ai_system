const { createClient } = require('@supabase/supabase-js');
const path = require('path');
require('dotenv').config({ path: 'c:/Users/ACER/Desktop/OJT _AI_SYSTEM/backend/config/env/.env' });

console.log('SUPABASE_URL:', process.env.SUPABASE_URL);

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function check() {
  try {
    const { data, error, count } = await supabase.from('users').select('*', { count: 'exact', head: true });
    if (error) throw error;
    console.log('✅ Supabase API connection successful. Users count:', count);
  } catch (err) {
    console.error('❌ Supabase API connection failed:', err);
  }
}

check();
