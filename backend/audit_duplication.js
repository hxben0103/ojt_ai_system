const { query } = require('./config/db');

async function checkDuplication() {
    console.log('🔍 Checking for duplicate triggers/logic on attendance table...');
    
    try {
        // 1. List all triggers on the attendance table
        const triggers = await query(`
            SELECT trigger_name, event_manipulation, action_statement, action_timing
            FROM information_schema.triggers
            WHERE event_object_table = 'attendance'
        `);
        
        console.log('\n--- Triggers Found ---');
        triggers.rows.forEach(t => {
            console.log(`- ${t.trigger_name} (${t.action_timing} ${t.event_manipulation})`);
        });

        // 2. Check if total_hours is calculated in any stored procedures
        // We'll search for 'total_hours' in the routines
        const procs = await query(`
            SELECT routine_name, routine_definition 
            FROM information_schema.routines 
            WHERE routine_type = 'FUNCTION' 
            AND routine_schema = 'public'
            AND routine_definition LIKE '%total_hours%'
        `);

        console.log('\n--- Related Stored Procedures ---');
        procs.rows.forEach(p => {
            console.log(`- ${p.routine_name}`);
        });

        // 3. Inspect backend for manual calculations
        console.log('\n--- Manual Checks (Requires Grep) ---');
        
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

checkDuplication();
