const { Client } = require('pg');
const fs = require('fs');
const url = 'postgresql://postgres:-Mark%401213%40%40%40@db.vykprjzttyjpnptzbinl.supabase.co:5432/postgres';
const c = new Client({ connectionString: url, ssl: false });
c.connect()
    .then(() => c.query("SELECT column_name FROM information_schema.columns WHERE table_name='attendance'"))
    .then(r => fs.writeFileSync('cols.json', JSON.stringify(r.rows)))
    .catch(console.error)
    .finally(() => c.end());
