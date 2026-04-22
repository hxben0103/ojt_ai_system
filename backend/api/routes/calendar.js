const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');
const authenticateToken = require('../middleware/auth');

// Auto-initialize calendar table + seed PH holidays
(async () => {
  try {
    await query(`
      CREATE TABLE IF NOT EXISTS university_calendar (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        event_type VARCHAR(50) NOT NULL DEFAULT 'holiday',
        start_date DATE NOT NULL,
        end_date DATE NOT NULL,
        is_recurring BOOLEAN DEFAULT false,
        created_by INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      )
    `);
    await query(`CREATE INDEX IF NOT EXISTS idx_calendar_dates ON university_calendar(start_date, end_date)`);

    // Seed Philippine National Holidays if table is empty
    const existing = await query('SELECT COUNT(*) as cnt FROM university_calendar');
    if (parseInt(existing.rows[0].cnt) === 0) {
      const currentYear = new Date().getFullYear();
      const holidays = [
        // Regular Holidays
        { title: "New Year's Day", start: `${currentYear}-01-01`, end: `${currentYear}-01-01`, type: 'holiday', recurring: true },
        { title: "Araw ng Kagitingan (Day of Valor)", start: `${currentYear}-04-09`, end: `${currentYear}-04-09`, type: 'holiday', recurring: true },
        { title: "Maundy Thursday", start: `${currentYear}-04-17`, end: `${currentYear}-04-17`, type: 'holiday', recurring: false },
        { title: "Good Friday", start: `${currentYear}-04-18`, end: `${currentYear}-04-18`, type: 'holiday', recurring: false },
        { title: "Black Saturday", start: `${currentYear}-04-19`, end: `${currentYear}-04-19`, type: 'holiday', recurring: false },
        { title: "Labor Day", start: `${currentYear}-05-01`, end: `${currentYear}-05-01`, type: 'holiday', recurring: true },
        { title: "Independence Day", start: `${currentYear}-06-12`, end: `${currentYear}-06-12`, type: 'holiday', recurring: true },
        { title: "National Heroes Day", start: `${currentYear}-08-25`, end: `${currentYear}-08-25`, type: 'holiday', recurring: true },
        { title: "Bonifacio Day", start: `${currentYear}-11-30`, end: `${currentYear}-11-30`, type: 'holiday', recurring: true },
        { title: "Christmas Day", start: `${currentYear}-12-25`, end: `${currentYear}-12-25`, type: 'holiday', recurring: true },
        { title: "Rizal Day", start: `${currentYear}-12-30`, end: `${currentYear}-12-30`, type: 'holiday', recurring: true },
        { title: "Last Day of the Year", start: `${currentYear}-12-31`, end: `${currentYear}-12-31`, type: 'holiday', recurring: true },

        // Special Non-Working Holidays
        { title: "Chinese New Year", start: `${currentYear}-01-29`, end: `${currentYear}-01-29`, type: 'holiday', recurring: false },
        { title: "EDSA People Power Anniversary", start: `${currentYear}-02-25`, end: `${currentYear}-02-25`, type: 'holiday', recurring: true },
        { title: "Ninoy Aquino Day", start: `${currentYear}-08-21`, end: `${currentYear}-08-21`, type: 'holiday', recurring: true },
        { title: "All Saints' Day", start: `${currentYear}-11-01`, end: `${currentYear}-11-01`, type: 'holiday', recurring: true },
        { title: "All Souls' Day", start: `${currentYear}-11-02`, end: `${currentYear}-11-02`, type: 'holiday', recurring: true },
        { title: "Feast of the Immaculate Conception", start: `${currentYear}-12-08`, end: `${currentYear}-12-08`, type: 'holiday', recurring: true },
        { title: "Christmas Eve", start: `${currentYear}-12-24`, end: `${currentYear}-12-24`, type: 'holiday', recurring: true },

        // Common University Events
        { title: "Midterm Examination Week", start: `${currentYear}-10-14`, end: `${currentYear}-10-18`, type: 'exam_week', recurring: false },
        { title: "Final Examination Week", start: `${currentYear}-12-09`, end: `${currentYear}-12-13`, type: 'exam_week', recurring: false },
        { title: "Christmas Break", start: `${currentYear}-12-20`, end: `${currentYear + 1}-01-05`, type: 'holiday', recurring: false },
      ];

      for (const h of holidays) {
        await query(
          `INSERT INTO university_calendar (title, event_type, start_date, end_date, is_recurring) VALUES ($1, $2, $3, $4, $5)`,
          [h.title, h.type, h.start, h.end, h.recurring]
        );
      }
      console.log(`✅ University calendar seeded with ${holidays.length} Philippine events`);
    } else {
      console.log('✅ University calendar table verified');
    }
  } catch (error) {
    console.error('❌ Error initializing university calendar:', error);
  }
})();

// Get all calendar events
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { year } = req.query;
    let sql = 'SELECT * FROM university_calendar';
    const params = [];

    if (year) {
      sql += ' WHERE EXTRACT(YEAR FROM start_date) = $1 OR EXTRACT(YEAR FROM end_date) = $1';
      params.push(parseInt(year));
    }

    sql += ' ORDER BY start_date ASC';
    const result = await query(sql, params);
    res.json({ events: result.rows });
  } catch (error) {
    console.error('Get calendar events error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Check if a specific date is blocked
router.get('/is-blocked', authenticateToken, async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) return res.status(400).json({ error: 'date query parameter is required (YYYY-MM-DD)' });

    const result = await query(
      `SELECT title, event_type FROM university_calendar WHERE $1::date BETWEEN start_date AND end_date LIMIT 1`,
      [date]
    );

    if (result.rows.length > 0) {
      res.json({ blocked: true, reason: result.rows[0].title, type: result.rows[0].event_type });
    } else {
      res.json({ blocked: false });
    }
  } catch (error) {
    console.error('Check blocked date error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create a new calendar event (Admin only)
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { role, user_id } = req.user;
    if (role !== 'Admin') {
      return res.status(403).json({ error: 'Only Admin can create calendar events' });
    }

    const { title, event_type, start_date, end_date, is_recurring } = req.body;

    if (!title || !start_date || !end_date) {
      return res.status(400).json({ error: 'title, start_date, and end_date are required' });
    }

    const result = await query(
      `INSERT INTO university_calendar (title, event_type, start_date, end_date, is_recurring, created_by)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [title, event_type || 'holiday', start_date, end_date, is_recurring || false, user_id]
    );

    res.status(201).json({ event: result.rows[0], message: 'Calendar event created' });
  } catch (error) {
    console.error('Create calendar event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete a calendar event (Admin only)
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const { role } = req.user;
    if (role !== 'Admin') {
      return res.status(403).json({ error: 'Only Admin can delete calendar events' });
    }

    const { id } = req.params;
    const result = await query(
      'DELETE FROM university_calendar WHERE id = $1 RETURNING *',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Event not found' });
    }

    res.json({ message: 'Event deleted', event: result.rows[0] });
  } catch (error) {
    console.error('Delete calendar event error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
