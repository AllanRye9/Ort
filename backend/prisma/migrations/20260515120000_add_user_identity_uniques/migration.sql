-- Enforce uniqueness for key account identity fields
ALTER TABLE "User" ADD CONSTRAINT "User_phone_key" UNIQUE ("phone");
ALTER TABLE "User" ADD CONSTRAINT "User_registrationNumber_key" UNIQUE ("registrationNumber");
ALTER TABLE "User" ADD CONSTRAINT "User_agentLicense_key" UNIQUE ("agentLicense");
