const fs = require('fs');
const path = require('path');
const { query } = require('./config/db');

async function runMigration() {
    console.log('🚀 Starting Student Requirements Migration...');
    
    try {
        const sqlPath = path.join(__dirname, '../database/migration_student_requirements.sql');
        console.log(`Reading SQL from: ${sqlPath}`);
        
        const sql = fs.readFileSync(sqlPath, 'utf8');
        
        // Execute the entire SQL script
        // Note: For multiple statements, some drivers need them split, 
        // but pg.Pool.query can often handle multiple commands if separated by semicolons.
        await query(sql);
        
        console.log('✅ Migration completed successfully!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration failed:');
        console.error(error);
        process.exit(1);
    }
}

runMigration();
