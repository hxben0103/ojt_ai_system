const { query } = require('./config/db');

async function migrate() {
    console.log('🚀 Running Database Migration (Face Verification Columns)...');
    try {
        await query(`
            ALTER TABLE attendance 
            ADD COLUMN IF NOT EXISTS face_match_score NUMERIC DEFAULT 0,
            ADD COLUMN IF NOT EXISTS is_face_verified BOOLEAN DEFAULT FALSE;
        `);
        console.log('✅ Migration successful: face_match_score and is_face_verified added to attendance table.');
        process.exit(0);
    } catch (err) {
        console.error('❌ Migration failed:', err.message);
        process.exit(1);
    }
}

migrate();
