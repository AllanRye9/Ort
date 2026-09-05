-- Site optimization pass: Order, Message, Notification, Withdrawal,
-- Favorite, ProductReview and StoreRental were queried heavily by
-- foreign-key columns (buyerId/sellerId, senderId/receiverId, userId,
-- listingId) with no supporting index — every such query was a full
-- table scan. Prisma/Postgres do NOT auto-index foreign key columns,
-- unlike some ORMs, so these have to be declared explicitly.

CREATE INDEX "Order_buyerId_status_createdAt_idx"  ON "Order"("buyerId", "status", "createdAt" DESC);
CREATE INDEX "Order_sellerId_status_createdAt_idx" ON "Order"("sellerId", "status", "createdAt" DESC);

CREATE INDEX "OrderItem_listingId_idx" ON "OrderItem"("listingId");
CREATE INDEX "OrderItem_orderId_idx"   ON "OrderItem"("orderId");

CREATE INDEX "Notification_userId_read_createdAt_idx" ON "Notification"("userId", "read", "createdAt" DESC);

CREATE INDEX "Withdrawal_userId_createdAt_idx" ON "Withdrawal"("userId", "createdAt" DESC);

CREATE INDEX "Message_senderId_createdAt_idx"   ON "Message"("senderId", "createdAt" DESC);
CREATE INDEX "Message_receiverId_createdAt_idx" ON "Message"("receiverId", "createdAt" DESC);
CREATE INDEX "Message_receiverId_read_idx"      ON "Message"("receiverId", "read");

CREATE INDEX "Favorite_listingId_idx" ON "Favorite"("listingId");

CREATE INDEX "ProductReview_listingId_status_idx" ON "ProductReview"("listingId", "status");

CREATE INDEX "StoreRental_userId_status_idx"  ON "StoreRental"("userId", "status");
CREATE INDEX "StoreRental_status_endDate_idx" ON "StoreRental"("status", "endDate");
