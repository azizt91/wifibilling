// netlify/functions/send-wa.js
// Serverless backend untuk mengirim WhatsApp Fonnte secara aman tanpa membocorkan token ke frontend

export async function handler(event, context) {
  // CORS Headers
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Content-Type': 'application/json'
  };

  // Preflight
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers, body: '' };
  }

  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      headers,
      body: JSON.stringify({ error: 'Method Not Allowed' })
    };
  }

  try {
    const body = JSON.parse(event.body || '{}');
    const { target, message } = body;

    if (!target || !message) {
      return {
        statusCode: 400,
        headers,
        body: JSON.stringify({ error: 'Target phone and message are required' })
      };
    }

    // Token diambil dari Netlify Environment Variables (aman di server)
    const token = process.env.FONNTE_TOKEN || 'q3yqhiRwa2UXzpwGydZ2';

    const formData = new URLSearchParams();
    formData.append('target', String(target));
    formData.append('message', String(message));
    formData.append('countryCode', '62');

    const response = await fetch('https://api.fonnte.com/send', {
      method: 'POST',
      headers: {
        'Authorization': token,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: formData.toString()
    });

    const data = await response.json();

    return {
      statusCode: response.ok ? 200 : response.status,
      headers,
      body: JSON.stringify(data)
    };
  } catch (error) {
    console.error('Fonnte dispatch server error:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: error.message || 'Gagal mengirim pesan WhatsApp' })
    };
  }
}
