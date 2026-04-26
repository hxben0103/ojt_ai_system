const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');
const authenticateToken = require('../middleware/auth');

// POST /ojt-sites - Create (auth)
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { name, latitude, longitude, radius_meters, company_id, company_name, address } = req.body;
    if (!name || latitude == null || longitude == null) {
      return res.status(400).json({ error: 'name, latitude, longitude are required' });
    }
    const radius = radius_meters != null ? Number(radius_meters) : 100;
    const result = await query(
      `INSERT INTO ojt_sites (name, latitude, longitude, radius_meters, company_id, company_name, address, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP)
       RETURNING id, name, latitude, longitude, radius_meters, company_id, company_name, address, created_at`,
      [name, latitude, longitude, radius, company_id || null, company_name || null, address || null]
    );
    res.status(201).json({ site: result.rows[0] });
  } catch (err) {
    console.error('Create ojt_site error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /ojt-sites?companyId=... or ?company_name=... (list; must be before /:id)
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { companyId, company_name } = req.query;
    let sql = 'SELECT id, name, latitude, longitude, radius_meters, company_id, company_name, address, created_at FROM ojt_sites WHERE 1=1';
    const params = [];
    let p = 1;
    if (companyId != null && companyId !== '') {
      sql += ` AND company_id = $${p++}`;
      params.push(companyId);
    }
    if (company_name != null && company_name !== '') {
      sql += ` AND company_name = $${p++}`;
      params.push(company_name);
    }
    sql += ' ORDER BY name';
    const result = await query(sql, params);
    res.json({ sites: result.rows });
  } catch (err) {
    console.error('List ojt_sites error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /ojt-sites/:id
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const result = await query(
      'SELECT id, name, latitude, longitude, radius_meters, company_id, company_name, address, created_at FROM ojt_sites WHERE id = $1',
      [id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Site not found' });
    res.json({ site: result.rows[0] });
  } catch (err) {
    console.error('Get ojt_site error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /ojt-sites/:id
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { name, latitude, longitude, radius_meters, company_id, company_name, address } = req.body;
    const updates = [];
    const values = [];
    let p = 1;
    if (name != null) { updates.push(`name = $${p++}`); values.push(name); }
    if (latitude != null) { updates.push(`latitude = $${p++}`); values.push(latitude); }
    if (longitude != null) { updates.push(`longitude = $${p++}`); values.push(longitude); }
    if (radius_meters != null) { updates.push(`radius_meters = $${p++}`); values.push(radius_meters); }
    if (company_id !== undefined) { updates.push(`company_id = $${p++}`); values.push(company_id); }
    if (company_name !== undefined) { updates.push(`company_name = $${p++}`); values.push(company_name); }
    if (address !== undefined) { updates.push(`address = $${p++}`); values.push(address); }
    if (updates.length === 0) return res.status(400).json({ error: 'No fields to update' });
    values.push(id);
    await query(
      `UPDATE ojt_sites SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $${p}`,
      values
    );
    const result = await query(
      'SELECT id, name, latitude, longitude, radius_meters, company_id, company_name, address, created_at FROM ojt_sites WHERE id = $1',
      [id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Site not found' });
    res.json({ site: result.rows[0] });
  } catch (err) {
    console.error('Update ojt_site error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
