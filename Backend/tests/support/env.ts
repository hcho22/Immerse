// Points the functions under test at the stand-ins: the R2 stand-in started for the run, and nothing real. The push
// and Clerk tests set their own stand-ins' addresses.
import { inject } from "vitest";

const storage = inject("storage");
process.env.R2_ENDPOINT = storage.endpoint;
process.env.R2_BUCKET = storage.bucket;
process.env.R2_ACCESS_KEY_ID = storage.accessKeyId;
process.env.R2_SECRET_ACCESS_KEY = storage.secretAccessKey;
process.env.R2_REGION = storage.region;
