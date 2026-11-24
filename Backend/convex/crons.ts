// The server's one recurring job: reports resolved more than 90 days ago are deleted (section 8). Everything else that
// happens at a time is scheduled for its event (schedule.ts).
import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();
crons.daily("expire resolved reports", { hourUTC: 4, minuteUTC: 0 }, internal.reports.expireResolved, {});
export default crons;
