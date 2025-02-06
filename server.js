const express = require('express');
const bodyParser = require('body-parser');
const axios = require('axios');
const mariadb = require('mariadb');

// Create the Express app
const app = express();
app.use(bodyParser.json());

// Configure the MariaDB connection pool
const pool = mariadb.createPool({
    user: 'david',
    host: 'localhost',
    database: 'lucky_deck_gaming',
    password: 'OMGunibet2025##', // Replace with your actual DB password
    port: 3306, // MariaDB default port
});

// Endpoint to handle email submissions
app.post('/submit-email', async (req, res) => {
    const { email } = req.body;

    // Validate the request payload
    if (!email) {
        return res.status(400).json({ error: 'Email is required' });
    }

    try {
        // Get the user's IP address
        const ip = req.headers['x-forwarded-for'] || req.connection.remoteAddress;

        // Fetch geolocation data using ipinfo.io
        let country = 'Unknown';
        try {
            const geoResponse = await axios.get(`https://ipinfo.io/${ip}/json?token=274528d88adb69`);
            country = geoResponse.data.country || 'Unknown';
        } catch (geoError) {
            console.error('Error with geolocation API:', geoError.response?.data || geoError.message);
        }

        // Insert the email and country into the database
        const conn = await pool.getConnection();
        const result = await conn.query(
            'INSERT INTO emails (email, country) VALUES (?, ?)',
            [email, country]
        );
        conn.release();

        // Convert BigInt to string for JSON serialization
        const insertId = result.insertId ? result.insertId.toString() : null;

        // Send a successful response
        res.status(200).json({
            success: true,
            data: { id: insertId, email, country },
        });
    } catch (error) {
        console.error('Error processing request:', error.message);
        res.status(500).json({ error: 'Server error' });
    }
});

// Start the Express server
const PORT = 3001;
app.listen(PORT, () => {
    console.log(`Email API is running on port ${PORT}`);
});
