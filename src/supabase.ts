import { createClient } from '@supabase/supabase-js'
import type { Database } from './types/supabase-generated';

// Create a single supabase client for interacting with your database
const supabase = createClient<Database>(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
)

export default supabase;
