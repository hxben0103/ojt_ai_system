const fs = require('fs');
const path = require('path');
const { query } = require('../config/db');

async function applyMigration() {
    const migrationFile = 'migration_v5_unified_timing.sql';
    console.log(`🚀 Applying Unified Logic Migration: ${migrationFile}`);
    
    try {
        const sqlPath = path.join(__dirname, '../../database', migrationFile);
        console.log(`Reading SQL from: ${sqlPath}`);
        
        const sql = fs.readFileSync(sqlPath, 'utf8');
        
        // Split by semicolons for safer execution if needed, 
        // but pg.query handles multiple commands usually.
        await query(sql);
        
        console.log('✅ Unified Timing Logic applied successfully!');
        
        // Audit after update
        const stats = await query('SELECT count(*) as count, SUM(total_hours) as total FROM attendance');
        console.log(`Audited ${stats.rows[0].count} records. New Total Hours across system: ${stats.rows[0].total}`);
        
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration failed:', error.message);
        process.exit(1);
    }
}

applyMigration();
