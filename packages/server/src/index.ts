import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { jwt, sign } from 'hono/jwt'
import db from './db/index.js'
import { randomUUID } from 'node:crypto'

const JWT_SECRET = process.env.JWT_SECRET!
const app = new Hono()

app.use('*', cors())


app.get('/', async (c) => {
  try {
    const result = await db.query('SELECT * FROM users', [])
    return c.json(result.rows)
  } catch (error) {
    return c.text((error as Error).message, 500)
  }
})

app.post('/login', async (c) => {
  const { email, password } = await c.req.json()
  const result = await db.query('SELECT * FROM users WHERE email = $1', [email])
  if(result.rows.length === 0) {
    return c.json({ error: 'User not found' }, 400)
  }

  const user = result.rows[0]
  if(user.password_hash !== password) {
    return c.json({ error: 'Invalid password' }, 400)
  }
  const payload = {
    sub: user.email,
    userId:user.id,
    exp: Math.floor(Date.now() / 1000) + 60 * 5
  }
  const token = await sign(payload, JWT_SECRET);
  return c.json({ token })
})


app.get('/generate-qrcode', async (c) => {
  const token = randomUUID()
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000); 
  await db.query('INSERT INTO qr_sessions (token, expires_at) VALUES ($1, $2)', [token, expiresAt])
  return c.json({ token })
})

app.get('/check-qrcode/:token', async (c) => {
  const { token } = c.req.param()
  const result = await db.query('SELECT * FROM qr_sessions WHERE token = $1 AND expires_at > NOW()', [token])
  if (result.rows.length === 0) {
    return c.json({ error: 'Invalid or expired QR code' }, 400)
  }
  const session = result.rows[0]
  if(session.status === 'confirmed') {
    const userId = session.user_id
    if (!userId) {
      return c.json({ error: 'Session confirmed but user_id is missing' }, 500);
    }
    
    const payload = {
      sub: userId,
      iat: Math.floor(Date.now() / 1000),
      exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 7)
    }
    
    const authToken = await sign(payload, JWT_SECRET)
    return c.json({ status: 'confirmed', authToken }, 200)
  }
  return c.json({ status:'pending', authToken: null }, 200)
})

app.post('/confirm-login', jwt({secret: JWT_SECRET}), async (c) => {
  const { scannedToken } = await c.req.json();
  const payload = c.get('jwtPayload');
  const userId = payload?.userId;
  if(!scannedToken) {
    return c.json({ error: 'Scanned token is required' }, 400)
  }

  const result = await db.query('SELECT * FROM qr_sessions WHERE token = $1 AND expires_at > NOW()', [scannedToken])
  if (result.rows.length === 0) {
    return c.json({ error: 'Invalid or expired QR code' }, 400)
  }

  if(result.rows[0].status !== 'pending') {
    return c.json({ error: 'QR code already confirmed' }, 400)
  }

  await db.query('UPDATE qr_sessions SET status = $1, user_id = $2 WHERE token = $3', ['confirmed', userId, scannedToken])
  return c.json({ message: 'QR code confirmed' }, 200)
})

app.get('/protected', jwt({secret: JWT_SECRET}), async (c) => {
  const payload = c.get('jwtPayload');
  return c.json({message: 'Hello, '+payload.sub}, 200)
})


serve({
  fetch: app.fetch,
  port: 3001
}, (info) => {
  console.log(`Server is running on http://localhost:${info.port}`)
})
