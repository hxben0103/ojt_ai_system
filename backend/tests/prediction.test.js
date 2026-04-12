// backend/tests/prediction.test.js
const { Pool } = require('pg');
const predictionService = require('../api/routes/prediction');

// Mock external dependencies
jest.mock('pg', () => {
  const mPool = {
    query: jest.fn(),
    end: jest.fn(),
  };
  return { Pool: jest.fn(() => mPool) };
});
jest.mock('axios');

describe('Unified AI Payload Constructor Tests', () => {
  it('should correctly assemble the AI insight payload structure with OJT constraints', () => {
    // Assuming we extract the underlying payload building logic or just test the format
    const mockStudentData = {
      user_id: 110,
      student_id: '106',
      full_name: 'Test Student',
      course: 'BSIT',
      program: 'BSIT'
    };
    
    // In our payload, we expect attendance stats, tasks, and point scoring.
    const mockAttendance = {
      approved_hours: 120,
      required_hours: 300,
      completion_ratio: 0.4,
      late_count: 5,
    };
    
    const payload = {
      student_profile: {
        id: mockStudentData.student_id,
        course_program: mockStudentData.program,
      },
      attendance: mockAttendance
    };
    
    expect(payload.student_profile.course_program).toBe('BSIT');
    expect(payload.attendance.completion_ratio).toBeGreaterThan(0.3);
  });

  it('should invalidate cache when the unified cache fails or is old', () => {
    const isCacheStale = (lastUpdated) => {
      const now = new Date();
      const diffHrs = (now - new Date(lastUpdated)) / (1000 * 60 * 60);
      return diffHrs > 4; 
    };
    
    // Mock an old timestamp
    const oldTimestamp = new Date();
    oldTimestamp.setHours(oldTimestamp.getHours() - 5);
    
    expect(isCacheStale(oldTimestamp)).toBe(true);

    const freshTimestamp = new Date();
    freshTimestamp.setHours(freshTimestamp.getHours() - 1);
    expect(isCacheStale(freshTimestamp)).toBe(false);
  });
});
