const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: './config/env/.env' });

const BUCKET = 'attendance-photos';

// Only initialize Supabase client if credentials are properly set
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

const isConfigured =
    supabaseUrl &&
    supabaseKey &&
    supabaseUrl.startsWith('https://') &&
    !supabaseUrl.includes('<YOUR_PROJECT_REF>');

let supabase = null;
if (isConfigured) {
    supabase = createClient(supabaseUrl, supabaseKey);
    console.log('✅ Supabase Storage client initialized');
} else {
    console.warn('⚠️  Supabase credentials not configured — photo uploads will return errors until .env is updated.');
}

/**
 * Upload an attendance photo to Supabase Storage.
 *
 * @param {Buffer} fileBuffer  - The raw file bytes (from multer memory storage)
 * @param {string} fileName    - Unique file name, e.g. attendance_42_1709380000000_checkin.jpg
 * @param {string} mimeType    - MIME type, e.g. image/jpeg
 * @returns {{ path: string, publicUrl: string } | { error: string }}
 */
async function uploadAttendancePhoto(fileBuffer, fileName, mimeType) {
    if (!supabase) {
        return { error: 'Supabase Storage is not configured. Please set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in your .env file.' };
    }

    try {
        const { data, error } = await supabase.storage
            .from(BUCKET)
            .upload(fileName, fileBuffer, {
                contentType: mimeType || 'image/jpeg',
                upsert: false,
            });

        if (error) {
            console.error('❌ Supabase Storage upload error:', error.message);
            return { error: `Upload failed: ${error.message}` };
        }

        // Build the public URL for the uploaded file
        const { data: urlData } = supabase.storage
            .from(BUCKET)
            .getPublicUrl(data.path);

        return {
            path: data.path,
            publicUrl: urlData.publicUrl,
        };
    } catch (err) {
        console.error('❌ Supabase Storage unexpected error:', err);
        return { error: `Upload failed: ${err.message}` };
    }
}

module.exports = { supabase, uploadAttendancePhoto, BUCKET };
