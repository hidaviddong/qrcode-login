import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import db from './db/index.js'

const app = new Hono()


app.get('/', async (c) => {
  try {
    const result = await db.query('SELECT * FROM users', [])
    return c.json(result.rows)
  } catch (error) {
    return c.text((error as Error).message, 500)
  }
})

serve({
  fetch: app.fetch,
  port: 3001
}, (info) => {
  console.log(`Server is running on http://localhost:${info.port}`)
})
