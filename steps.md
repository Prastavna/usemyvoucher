# UseMyVoucher.com - Step-by-Step Build Guide

## Instructions
- Complete each step in order
- Check if a step is completed before moving to the next
- Do not skip steps
- Test each step before proceeding

---

## Phase 1: Project Setup & Foundation

### Step 1: Initialize Project
- [ ] Create Vite + Vue + TypeScript project using Bun
- [ ] Install all dependencies (Supabase, Vue Router, NuxtUI, Tailwind)
- [ ] Configure Tailwind CSS
- [ ] Set up path aliases in vite.config.ts
- [ ] Verify project runs with `bun run dev`

### Step 2: Environment Configuration
- [ ] Create .env file
- [ ] Add Supabase URL and anon key
- [ ] Add .env to .gitignore
- [ ] Test environment variables are loading

### Step 3: Supabase Client Setup
- [ ] Create lib/supabase.ts file
- [ ] Initialize Supabase client with environment variables
- [ ] Export client for use across app
- [ ] Test connection to Supabase

### Step 4: Project Structure
- [ ] Create folder structure (components, views, composables, lib, router)
- [ ] Set up main.css with Tailwind imports
- [ ] Configure main.ts with router
- [ ] Create basic App.vue structure

---

## Phase 2: Authentication & Routing

### Step 5: Router Configuration
- [ ] Create router/index.ts file
- [ ] Define all routes (landing, browse, voucher detail, submit, my vouchers, leaderboard, profile)
- [ ] Add meta fields for authentication requirements
- [ ] Implement navigation guard to check authentication
- [ ] Test route protection (unauthenticated should redirect to landing)

### Step 6: Authentication Composable
- [ ] Create composables/useAuth.ts
- [ ] Implement user state management
- [ ] Create signIn function with Google OAuth
- [ ] Create signOut function
- [ ] Create fetchUser function
- [ ] Test composable works

### Step 7: Landing Page
- [ ] Create views/Landing.vue
- [ ] Add hero section with value proposition
- [ ] Add "Sign in with Google" button
- [ ] Wire up Google OAuth sign-in
- [ ] Add brief explanation of platform
- [ ] Ensure NO voucher data is displayed
- [ ] Test Google authentication flow

### Step 8: App Layout & Navigation
- [ ] Create App.vue with navigation bar
- [ ] Add logo/site name
- [ ] Add navigation links (Browse, Submit, My Vouchers, Leaderboard)
- [ ] Add user avatar/menu dropdown
- [ ] Add Sign Out option in dropdown
- [ ] Show navigation only when authenticated
- [ ] Test navigation and sign out

---

## Phase 3: Browse & View Vouchers

### Step 9: Browse Page Setup
- [ ] Create views/Browse.vue
- [ ] Fetch all active, non-deleted vouchers from Supabase
- [ ] Display loading state while fetching
- [ ] Handle errors gracefully

### Step 10: Voucher Card Component
- [ ] Create components/VoucherCard.vue
- [ ] Display merchant name, discount value, category, expiry date
- [ ] Display use count / max uses
- [ ] Add click handler to navigate to detail page
- [ ] Style card with minimal design
- [ ] Test card displays data correctly

### Step 11: Browse Page Features
- [ ] Display vouchers in grid layout
- [ ] Add search functionality (filter by merchant name)
- [ ] Add category filter dropdown
- [ ] Add sort options (newest, most used, expiring soon)
- [ ] Implement filters and sorting
- [ ] Add empty state when no vouchers found
- [ ] Test all filters and sorting work

### Step 12: Voucher Detail Page
- [ ] Create views/VoucherDetail.vue
- [ ] Fetch single voucher by ID from Supabase
- [ ] Display all voucher information
- [ ] Initially hide voucher code
- [ ] Add "Reveal Code" button
- [ ] On reveal, log view to voucher_views table
- [ ] Show voucher code in large text after reveal
- [ ] Add "Copy Code" button
- [ ] Test code reveal and copy functionality

### Step 13: Voucher Actions
- [ ] Add "I Used This Code" button on detail page
- [ ] Insert record into voucher_uses table on click
- [ ] Show success message after marking as used
- [ ] Disable button if already used by current user
- [ ] Add "Report Issue" button
- [ ] Test usage tracking works
- [ ] Test points are awarded correctly

---

## Phase 4: Submit Vouchers

### Step 14: Submit Page Form
- [ ] Create views/Submit.vue
- [ ] Add form with all required fields (merchant name, voucher code)
- [ ] Add optional fields (description, discount value, expiry date, category)
- [ ] Add max uses field (default: 1, min: 1)
- [ ] Implement form validation
- [ ] Style form with minimal design

### Step 15: Submit Functionality
- [ ] Wire up form submission to Supabase
- [ ] Insert voucher into vouchers table
- [ ] Handle success and error states
- [ ] Show success message on submission
- [ ] Redirect to voucher detail page after submission
- [ ] Clear form after successful submission
- [ ] Test voucher submission end-to-end
- [ ] Verify points are awarded

---

## Phase 5: User Vouchers

### Step 16: My Vouchers Page
- [ ] Create views/MyVouchers.vue
- [ ] Fetch vouchers where user_id matches current user
- [ ] Include both active and soft-deleted vouchers
- [ ] Display vouchers in list/grid format

### Step 17: My Vouchers Features
- [ ] Show voucher status (Active/Deleted/Reported)
- [ ] Display use count and report count for each
- [ ] Add "Delete" button for each voucher
- [ ] Implement soft delete via Supabase RPC
- [ ] Show confirmation before deleting
- [ ] Add empty state when user has no vouchers
- [ ] Test soft delete functionality

---

## Phase 6: Reporting System

### Step 18: Report Modal Component
- [ ] Create components/ReportModal.vue
- [ ] Add reason dropdown (Code doesn't work, Expired, Wrong info, Duplicate, Other)
- [ ] Add optional text area for additional details
- [ ] Add submit button
- [ ] Style modal with minimal design

### Step 19: Report Functionality
- [ ] Wire up report modal on voucher detail page
- [ ] Submit report to voucher_reports table
- [ ] Handle unique constraint (prevent duplicate reports)
- [ ] Show success toast notification
- [ ] Close modal after successful submission
- [ ] Test reporting works
- [ ] Verify report count increments

---

## Phase 7: Leaderboard

### Step 20: Leaderboard Page
- [ ] Create views/Leaderboard.vue
- [ ] Fetch top users by points from profiles table
- [ ] Sort by points descending
- [ ] Limit to top 50 or 100 users

### Step 21: Leaderboard Display
- [ ] Display rank number for each user
- [ ] Show display name or email
- [ ] Show avatar if available
- [ ] Show total points
- [ ] Optionally show number of vouchers submitted
- [ ] Highlight current user's position
- [ ] Style as table or list with minimal design
- [ ] Test leaderboard displays correctly

---

## Phase 8: User Profile

### Step 22: Profile Page
- [ ] Create views/Profile.vue
- [ ] Fetch current user's profile from profiles table
- [ ] Display avatar, display name, email
- [ ] Display total points
- [ ] Display join date

### Step 23: Profile Statistics
- [ ] Fetch and display total vouchers submitted
- [ ] Fetch and display total vouchers used
- [ ] Fetch and display times user's vouchers were used by others
- [ ] Add optional edit display name feature
- [ ] Style profile page with minimal design
- [ ] Test profile displays correct data

---

## Phase 9: Polish & UX

### Step 24: Loading States
- [ ] Add loading spinners for all data fetching operations
- [ ] Add skeleton loaders for voucher cards
- [ ] Add loading state for form submissions
- [ ] Test all loading states work

### Step 25: Error Handling
- [ ] Add error messages for failed API calls
- [ ] Add error states for all components
- [ ] Add 404 page for invalid routes
- [ ] Handle authentication errors gracefully
- [ ] Test error handling scenarios

### Step 26: Toast Notifications
- [ ] Implement toast notification system
- [ ] Add success toasts (voucher submitted, code copied, etc.)
- [ ] Add error toasts (failed submission, etc.)
- [ ] Add info toasts (already reported, already used, etc.)
- [ ] Test all notifications work

### Step 27: Empty States
- [ ] Add empty state for browse page (no vouchers)
- [ ] Add empty state for my vouchers page
- [ ] Add empty state for search with no results
- [ ] Style empty states consistently
- [ ] Test all empty states display correctly

### Step 28: Responsive Design
- [ ] Test all pages on mobile viewport
- [ ] Adjust navigation for mobile (hamburger menu if needed)
- [ ] Ensure forms work on mobile
- [ ] Test voucher cards stack properly on mobile
- [ ] Verify all buttons are touch-friendly
- [ ] Test on tablet viewport
- [ ] Fix any responsive issues

### Step 29: Accessibility
- [ ] Add proper ARIA labels to buttons
- [ ] Ensure keyboard navigation works
- [ ] Test with screen reader (basic check)
- [ ] Add focus states to interactive elements
- [ ] Ensure color contrast meets standards
- [ ] Test form validation messages are accessible

---

## Phase 10: Testing & Security

### Step 30: Authentication Testing
- [ ] Test Google OAuth sign-in flow
- [ ] Verify profile is created on first sign-in
- [ ] Test sign-out functionality
- [ ] Verify protected routes redirect when not authenticated
- [ ] Verify landing page shows no voucher data
- [ ] Test session persistence (refresh page while logged in)

### Step 31: Voucher Flow Testing
- [ ] Test voucher submission end-to-end
- [ ] Verify 10 points awarded on submission
- [ ] Test code reveal and logging to voucher_views
- [ ] Test "I Used This Code" awards correct points
- [ ] Test self-usage deducts points and soft deletes
- [ ] Test cannot use same voucher twice
- [ ] Test cannot use voucher beyond max_uses

### Step 32: Reporting & Moderation Testing
- [ ] Test report submission works
- [ ] Verify cannot report same voucher twice
- [ ] Check report count increments
- [ ] Verify vouchers with 3+ reports are auto-deactivated (wait for cron or check manually)

### Step 33: Security Audit
- [ ] Verify all routes except landing have authentication guards
- [ ] Check no API calls expose data to unauthenticated users
- [ ] Verify environment variables are not exposed in built code
- [ ] Test input sanitization on all forms
- [ ] Check for XSS vulnerabilities in user-generated content
- [ ] Verify RLS policies are working (try accessing data in browser console)

### Step 34: Edge Cases Testing
- [ ] Test with expired vouchers
- [ ] Test with deleted vouchers
- [ ] Test with reported vouchers
- [ ] Test with maxed-out multi-use vouchers
- [ ] Test network errors (disconnect internet)
- [ ] Test rapid clicking of buttons
- [ ] Test very long text inputs

---

## Phase 11: Deployment

### Step 35: Pre-Deployment
- [ ] Create production .env file
- [ ] Test production build locally (`bun run build && bun run preview`)
- [ ] Verify all features work in production build
- [ ] Check bundle size is reasonable

### Step 36: Deploy to Hosting
- [ ] Choose hosting platform (Vercel/Netlify/Cloudflare Pages)
- [ ] Connect repository
- [ ] Set environment variables in hosting dashboard
- [ ] Deploy application
- [ ] Verify deployment successful

### Step 37: Post-Deployment Testing
- [ ] Test Google OAuth on production domain
- [ ] Test all pages load correctly
- [ ] Test voucher submission on production
- [ ] Test all user flows end-to-end
- [ ] Check HTTPS is enforced
- [ ] Test on real mobile devices
- [ ] Verify performance (page load times)

### Step 38: Final Checks
- [ ] Verify Google OAuth settings are configured correctly in Supabase
- [ ] Test application with multiple test users
- [ ] Monitor for any errors in browser console
- [ ] Check Supabase logs for any errors
- [ ] Verify points system works correctly in production

---

## Completion Checklist

Before considering the project complete, ensure:
- [ ] All authentication flows work
- [ ] All voucher operations work (submit, view, use, report)
- [ ] Points system functions correctly
- [ ] Leaderboard displays accurately
- [ ] All pages are responsive
- [ ] Security measures are implemented
- [ ] Error handling is comprehensive
- [ ] User experience is smooth
- [ ] Application is deployed and accessible
- [ ] No critical bugs exist

---

## Notes

- Each checkbox represents a completed task
- Test thoroughly after each step
- If a step fails, debug before moving forward
- Security steps are non-negotiable
- Performance and UX improvements can be iterative
