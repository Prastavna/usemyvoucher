# UseMyVoucher.com - Build Specification

## Project Overview

Build a voucher/coupon listing platform where authenticated users can submit and use discount codes. Users earn points for submissions and usage, with a leaderboard tracking top contributors.

## Tech Stack

- **Frontend**: Vue.js 3 with TypeScript
- **Framework**: Nuxt 3
- **UI Library**: NuxtUI with Tailwind CSS
- **Routing**: Vue Router (built into Nuxt)
- **Backend**: Supabase (Authentication, Database, RLS)
- **Design**: Minimal, clean interface

## Database Schema

### Tables

#### profiles
```typescript
{
  id: UUID (references auth.users)
  email: TEXT
  display_name: TEXT
  avatar_url: TEXT
  points: INTEGER (default: 0)
  created_at: TIMESTAMPTZ
  updated_at: TIMESTAMPTZ
}
```

#### vouchers
```typescript
{
  id: UUID
  user_id: UUID (references profiles)
  merchant_name: TEXT
  voucher_code: TEXT
  description: TEXT
  discount_value: TEXT
  expiry_date: DATE
  category: TEXT
  is_active: BOOLEAN (default: true)
  report_count: INTEGER (default: 0)
  use_count: INTEGER (default: 0)
  max_uses: INTEGER (default: 1)
  deleted_at: TIMESTAMPTZ
  created_at: TIMESTAMPTZ
  updated_at: TIMESTAMPTZ
}
```

#### voucher_reports
```typescript
{
  id: UUID
  voucher_id: UUID (references vouchers)
  reporter_id: UUID (references profiles)
  reason: TEXT
  created_at: TIMESTAMPTZ
  UNIQUE(voucher_id, reporter_id)
}
```

#### voucher_views
```typescript
{
  id: UUID
  voucher_id: UUID (references vouchers)
  viewer_id: UUID (references profiles)
  viewed_at: TIMESTAMPTZ
  UNIQUE(voucher_id, viewer_id)
}
```

#### voucher_uses
```typescript
{
  id: UUID
  voucher_id: UUID (references vouchers)
  user_id: UUID (references profiles)
  used_at: TIMESTAMPTZ
  UNIQUE(voucher_id, user_id)
}
```

## Authentication

- **Single Sign-On**: Google OAuth only
- **Access Control**: All pages require authentication except landing page
- **Profile Creation**: Auto-create profile on first Google sign-in

## Points System

| Action | Points | Notes |
|--------|--------|-------|
| Submit voucher | +10 | Awarded on submission |
| Use someone's voucher | +5 | Awarded to user |
| Someone uses your voucher | +2 | Bonus to submitter |
| Use own voucher | -10 | Deducts submission points, soft deletes voucher |

## Core Features

### 1. Landing Page (Public)
- Hero section with value proposition
- "Sign in with Google" button
- Brief explanation of how platform works
- Minimal design with clean typography

### 2. Home/Browse Page (Authenticated)
- Display all active, non-deleted vouchers
- Grid/card layout showing:
  - Merchant name
  - Discount value
  - Category
  - Expiry date
  - Use count / max uses
- Filter by:
  - Category
  - Merchant name
  - Expiry date
- Search functionality
- Sort by:
  - Newest first
  - Most used
  - Expiring soon

### 3. Voucher Detail Page
- Full voucher information
- **Code reveal**: Initially hidden, click "Reveal Code" button
  - On reveal, log to `voucher_views` table
  - Show voucher code in large, copyable text
  - "Copy Code" button
- Action buttons:
  - "I Used This Code" - Creates entry in `voucher_uses`
  - "Report Issue" - Opens report modal
- Display usage stats: "Used X of Y times"
- Show submitter username (not clickable)
- Expiry countdown if within 7 days

### 4. Submit Voucher Page
- Form fields:
  - Merchant name (required, text input)
  - Voucher code (required, text input)
  - Description (optional, textarea)
  - Discount value (optional, text input, e.g., "20% off")
  - Expiry date (optional, date picker)
  - Category (optional, dropdown/select)
  - Max uses (required, number input, default: 1, min: 1)
- Submit button
- Success message on submission
- Redirect to voucher detail page after submission

### 5. My Vouchers Page
- List all vouchers submitted by logged-in user
- Show both active and soft-deleted vouchers
- Each voucher card shows:
  - All voucher details
  - Current use count
  - Report count
  - Status (Active/Deleted/Reported)
- Actions per voucher:
  - "Delete" button (soft delete via RPC)
  - View details

### 6. Leaderboard Page
- Table/list of top users by points
- Display:
  - Rank number
  - User display name or email
  - Avatar
  - Total points
  - Number of vouchers submitted
- Paginated (top 50 or 100)
- Highlight current user's position

### 7. Profile Page
- Display user info:
  - Avatar
  - Display name
  - Email
  - Total points
  - Join date
- Statistics:
  - Total vouchers submitted
  - Total vouchers used
  - Total times vouchers were used by others
- Edit display name (optional feature)

### 8. Report Modal
- Triggered from voucher detail page
- Form fields:
  - Reason (dropdown):
    - "Code doesn't work"
    - "Code expired"
    - "Wrong information"
    - "Duplicate"
    - "Other"
  - Additional details (optional textarea)
- Submit button
- Success toast notification
- Prevent duplicate reports (same user, same voucher)

## Business Logic

### Voucher Usage Rules
1. User can mark any voucher as "used" (including their own)
2. Self-usage:
   - Deducts 10 points from user
   - Soft deletes voucher (sets `deleted_at` timestamp)
   - No further usage allowed
3. Other user usage:
   - Awards 5 points to user who marked as used
   - Awards 2 bonus points to voucher submitter
   - Increments `use_count`
4. Multi-use vouchers:
   - Can be used multiple times until `use_count >= max_uses`
   - After max uses reached, no further usage allowed
5. One user can only mark a voucher as "used" once (UNIQUE constraint)

### Reporting System
1. Each user can report a voucher once
2. Each report increments `report_count` on voucher
3. Automated cron job (every 6 hours):
   - Deactivates vouchers with `report_count >= 3`
   - Sets `is_active = false`
4. Inactive vouchers do not appear in browse/search

### Soft Delete
1. User can manually soft delete their own vouchers
2. Soft deleted vouchers have `deleted_at` timestamp
3. Soft deleted vouchers do not appear in browse/search
4. Still visible on "My Vouchers" page with deleted status

## UI/UX Requirements

### Design Principles
- Minimal, clean interface
- High readability
- Clear call-to-action buttons
- Responsive design (mobile-first)
- Fast page loads
- Intuitive navigation

### Navigation
- Top navigation bar:
  - Logo/site name (left)
  - Browse | Submit | My Vouchers | Leaderboard (center)
  - User avatar/menu (right)
- User menu dropdown:
  - Profile
  - Sign out

### Color Scheme (Suggestion)
- Primary: Blue/Indigo for actions
- Success: Green for used/active vouchers
- Warning: Orange for expiring soon
- Error: Red for reported/deleted
- Neutral: Grays for text and backgrounds

### Typography
- Clean sans-serif font
- Clear hierarchy (headings vs body)
- Readable font sizes (minimum 16px body)

### Component Patterns
- Cards for voucher display
- Modals for reports, confirmations
- Toast notifications for success/error messages
- Loading states for async operations
- Empty states for no data

## Routing Structure

```
/ - Landing page (public)
/browse - Home/browse vouchers (authenticated)
/voucher/:id - Voucher detail (authenticated)
/submit - Submit new voucher (authenticated)
/my-vouchers - User's submitted vouchers (authenticated)
/leaderboard - Points leaderboard (authenticated)
/profile - User profile (authenticated)
```

## API Integration

### Supabase Client Setup
```typescript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NUXT_PUBLIC_SUPABASE_URL
const supabaseKey = process.env.NUXT_PUBLIC_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseKey)
```

### Authentication
```typescript
// Sign in with Google
await supabase.auth.signInWithOAuth({
  provider: 'google',
  options: {
    redirectTo: `${window.location.origin}/browse`
  }
})

// Sign out
await supabase.auth.signOut()

// Get current user
const { data: { user } } = await supabase.auth.getUser()
```

### Common Queries

#### Fetch all vouchers
```typescript
const { data, error } = await supabase
  .from('vouchers')
  .select(`
    *,
    profiles:user_id (display_name, email)
  `)
  .eq('is_active', true)
  .is('deleted_at', null)
  .order('created_at', { ascending: false })
```

#### Submit voucher
```typescript
const { data, error } = await supabase
  .from('vouchers')
  .insert({
    merchant_name: 'Amazon',
    voucher_code: 'SAVE20',
    description: '20% off electronics',
    discount_value: '20%',
    expiry_date: '2025-12-31',
    category: 'Electronics',
    max_uses: 1,
    user_id: user.id
  })
```

#### Mark voucher as used
```typescript
const { data, error } = await supabase
  .from('voucher_uses')
  .insert({
    voucher_id: voucherId,
    user_id: user.id
  })
```

#### Report voucher
```typescript
const { data, error } = await supabase
  .from('voucher_reports')
  .insert({
    voucher_id: voucherId,
    reporter_id: user.id,
    reason: 'Code doesn\'t work'
  })
```

#### Soft delete voucher
```typescript
const { data, error } = await supabase
  .rpc('soft_delete_voucher', {
    voucher_id_param: voucherId,
    user_id_param: user.id
  })
```

#### Fetch leaderboard
```typescript
const { data, error } = await supabase
  .from('profiles')
  .select('id, email, display_name, avatar_url, points')
  .order('points', { ascending: false })
  .limit(50)
```

#### Log voucher view
```typescript
const { data, error } = await supabase
  .from('voucher_views')
  .insert({
    voucher_id: voucherId,
    viewer_id: user.id
  })
```

## State Management

Use Vue 3 Composition API with composables:

### useAuth.ts
```typescript
export const useAuth = () => {
  const user = ref(null)
  const loading = ref(true)

  const fetchUser = async () => {
    const { data } = await supabase.auth.getUser()
    user.value = data.user
    loading.value = false
  }

  const signIn = async () => {
    await supabase.auth.signInWithOAuth({ provider: 'google' })
  }

  const signOut = async () => {
    await supabase.auth.signOut()
    user.value = null
  }

  return { user, loading, fetchUser, signIn, signOut }
}
```

### useProfile.ts
```typescript
export const useProfile = (userId: string) => {
  const profile = ref(null)
  const loading = ref(true)

  const fetchProfile = async () => {
    const { data } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single()
    profile.value = data
    loading.value = false
  }

  return { profile, loading, fetchProfile }
}
```

## Error Handling

- Display user-friendly error messages
- Use toast notifications for errors
- Log errors to console for debugging
- Handle Supabase RLS policy violations gracefully
- Handle unique constraint violations (duplicate reports, duplicate uses)
- Network error handling with retry options

## Performance Considerations

- Lazy load images
- Paginate voucher lists (infinite scroll or pagination)
- Cache frequently accessed data
- Optimize Supabase queries with proper indexing
- Use Nuxt's built-in code splitting

## Testing Checklist

### Authentication
- [ ] Google OAuth sign-in works
- [ ] Profile auto-created on first sign-in
- [ ] Protected routes redirect to login
- [ ] Sign out works correctly

### Voucher Submission
- [ ] Form validation works
- [ ] Voucher created with correct data
- [ ] 10 points awarded to submitter
- [ ] Redirect to voucher detail page

### Voucher Usage
- [ ] Code reveal works and logs view
- [ ] Copy code button works
- [ ] "I Used This Code" awards 5 points to user
- [ ] "I Used This Code" awards 2 points to submitter
- [ ] Self-usage deducts 10 points and soft deletes
- [ ] Cannot use same voucher twice
- [ ] Cannot use voucher after max_uses reached

### Reporting
- [ ] Report modal opens
- [ ] Report submission works
- [ ] Cannot report same voucher twice
- [ ] Report count increments
- [ ] Voucher deactivates after 3 reports (cron job)

### Leaderboard
- [ ] Top users displayed correctly
- [ ] Sorted by points descending
- [ ] Current user highlighted

### Soft Delete
- [ ] Manual delete works
- [ ] Deleted vouchers not visible in browse
- [ ] Deleted vouchers visible in My Vouchers

## Deployment

### Environment Variables
```
NUXT_PUBLIC_SUPABASE_URL=your_supabase_url
NUXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

### Supabase Setup
1. Create Supabase project
2. Run SQL schema from provided script
3. Enable Google OAuth in Authentication settings
4. Configure Google OAuth credentials
5. Set up cron job for report deactivation

### Build & Deploy
```bash
bun run build
bun run preview # test production build
```

Deploy to Vercel, Netlify, or any Nuxt-compatible hosting platform.

## Future Enhancements (Not Required for MVP)

- Email notifications for voucher usage
- Voucher expiry reminders
- Advanced search with filters
- User favorites/bookmarks
- Social sharing of vouchers
- Voucher categories with icons
- Admin panel for moderation
- API rate limiting
- User reputation system
- Voucher verification system
- Mobile app (React Native/Flutter)

## Notes

- Focus on core functionality first
- Ensure all RLS policies are correctly configured
- Test authentication flow thoroughly
- Validate all user inputs
- Handle edge cases (expired vouchers, deleted users, etc.)
- Ensure responsive design works on mobile
- Keep UI minimal and fast
- Prioritize user experience over feature complexity
