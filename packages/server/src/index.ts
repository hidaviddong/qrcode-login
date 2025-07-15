import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import { cors } from 'hono/cors'
import db from './db/index.js'
import { randomUUID } from 'node:crypto'

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
  const status = result.rows[0].status
  return c.json({ status }, 200)
})

serve({
  fetch: app.fetch,
  port: 3001
}, (info) => {
  console.log(`Server is running on http://localhost:${info.port}`)
})
