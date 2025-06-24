import express from 'express';
import jwt from 'jsonwebtoken';

const app = express();
app.use(express.json());

app.post('/get-token', (req, res) => {
  const { admin_api_key, url } = req.body;

  if (!admin_api_key || !url) {
    return res.status(400).json({ error: 'Missing admin_api_key or url' });
  }

  const [id, secret] = admin_api_key.split(':');

  const token = jwt.sign(
    {
      exp: Math.floor(Date.now() / 1000) + 5 * 60,
      aud: `/v5/admin/`
    },
    Buffer.from(secret, 'hex'),
    {
      keyid: id,
      algorithm: 'HS256',
      header: {
        alg: 'HS256',
        kid: id
      }
    }
  );

  res.json({ token });
});

app.listen(3000, () => {
  console.log('✅ Ghost Token Service running on port 3000');
});
