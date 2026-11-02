import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

const supabaseUrl = 'https://oawsmjpibfwpiaebvhot.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9hd3NtanBpYmZ3cGlhZWJ2aG90Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwODcyNTMsImV4cCI6MjEwODY2MzI1M30.7XUiwHh0UO4v9e8ZNPr_DbR9TgDAE0NZCbD62aMukYk';

export const supabase = createClient(supabaseUrl, supabaseKey);


