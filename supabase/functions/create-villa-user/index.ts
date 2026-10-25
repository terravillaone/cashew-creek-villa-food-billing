import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  try {
    const authHeader = req.headers.get('Authorization') || ''
    const token = authHeader.replace(/^Bearer\s+/i, '').trim()
    if (!token) return json({ error: 'Missing authorization token.' }, 401)

    const caller = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const { data: userData, error: userError } = await caller.auth.getUser(token)
    if (userError || !userData.user) return json({ error: 'Invalid session.' }, 401)

    const { data: profile, error: profileError } = await admin
      .from('profiles')
      .select('id,role')
      .eq('id', userData.user.id)
      .maybeSingle()

    if (profileError) throw profileError
    if (profile?.role !== 'owner') return json({ error: 'Only the owner can create users.' }, 403)

    const body = await req.json().catch(() => ({}))
    const username = String(body.username || '').trim().toLowerCase()
    const fullName = String(body.fullName || username).trim()
    const password = String(body.password || '')
    const role = String(body.role || 'caretaker').trim().toLowerCase()

    if (!/^[a-z0-9._-]{3,30}$/.test(username)) {
      return json({ error: 'Invalid user name.' }, 400)
    }
    if (password.length < 6) return json({ error: 'Password must be at least 6 characters.' }, 400)
    if (!['caretaker', 'guest', 'owner'].includes(role)) return json({ error: 'Invalid role.' }, 400)

    const { data: existing } = await admin
      .from('profiles')
      .select('id')
      .ilike('username', username)
      .maybeSingle()
    if (existing) return json({ error: `User name '${username}' already exists.` }, 409)

    const internalEmail = `${username}@login.cashewcreekvilla.local`
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email: internalEmail,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName, username },
    })
    if (createError) throw createError
    if (!created.user) throw new Error('Supabase did not return the new user.')

    const { error: profileUpsertError } = await admin.from('profiles').upsert({
      id: created.user.id,
      username,
      full_name: fullName,
      role,
    }, { onConflict: 'id' })

    if (profileUpsertError) {
      await admin.auth.admin.deleteUser(created.user.id)
      throw profileUpsertError
    }

    return json({ ok: true, user_id: created.user.id, username, role })
  } catch (error) {
    console.error(error)
    return json({ error: error instanceof Error ? error.message : 'User creation failed.' }, 400)
  }
})
