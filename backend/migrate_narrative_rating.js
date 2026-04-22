const { query } = require('./config/db');

async function migrate() {
    try {
        console.log('Starting migration: Adding rating column to student_progress_reports...');
        await query(`
            ALTER TABLE student_progress_reports 
            ADD COLUMN IF NOT EXISTS rating INT DEFAULT 0;
        `);
        console.log('✅ Migration complete: rating column added successfully.');
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration failed:', error);
        process.exit(1);
    }
}

migrate();
