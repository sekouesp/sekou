# Security Specification for ESP Sekou

## Data Invariants
1. A user can only edit their own profile (except for roles, which require super-admin).
2. Conversations can only be read/written by participants.
3. Broadcasts can only be created by admins or super-admins.
4. Users cannot change their own `role` or `isBureauMember` status.
5. Messages must belong to an existing conversation.

## The Dirty Dozen Payloads

1. **Self-Promotion**: Authenticated user trying to update their own `role` to 'super-admin'.
2. **Conversation Snooping**: User A trying to read a 'direct' conversation between User B and User C.
3. **Malicious Message**: User A trying to send a message into a conversation they are not a participant of.
4. **Broadcast Spoofing**: Regular user trying to create a document in the `broadcasts` collection.
5. **Config Tampering**: Non-admin user trying to update `/config/global`.
6. **ID Injection**: Trying to create a user profile with a 2KB string as a document ID.
7. **Profile Vandalism**: User A trying to update User B's `bio`.
8. **Shadow Field Injection**: Creating a user profile with an unauthorized field `isVerifiedByAdmin: true`.
9. **Message Spoofing**: User A sending a message with `senderId: 'userB_uid'`.
10. **Terminal State Break**: Attempting to delete a message (if we implement a non-delete policy).
11. **PII Leak**: Regular user trying to list all emails of students (if emails were public).
12. **Orphan Message**: Creating a message with a `conversationId` that doesn't exist.

## Test Runner (Draft Plan)
We will use standard Firebase security rule testing patterns to ensure these payloads are denied.
