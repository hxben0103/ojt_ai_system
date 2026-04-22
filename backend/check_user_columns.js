const { query } = require('./config/db');
async function checkColumns() {
    const res = await query("SELECT column_name FROM information_schema.columns WHERE table_name = 'users'");
    console.log(res.rows.map(r => r.column_name));
    process.exit(0);
}
checkColumns();
