import { CANNAGUIDE_SCHEMA_V1 } from './schema';

export const CANNAGUIDE_MIGRATIONS = [
  {
    version: 1,
    description: 'Initial schema — users, strains, sessions, profile, recommendations, ai_usage_log',
    sql: CANNAGUIDE_SCHEMA_V1,
  },
  {
    version: 2,
    description: 'Add THCA support + dispensary venue profile',
    sql: `
ALTER TABLE strains ADD COLUMN source_type TEXT;
ALTER TABLE dispensaries ADD COLUMN venue_type TEXT;
ALTER TABLE dispensaries ADD COLUMN vibe_rating INTEGER;
ALTER TABLE dispensaries ADD COLUMN price_tier TEXT;
ALTER TABLE dispensaries ADD COLUMN staff_rating INTEGER;
ALTER TABLE dispensaries ADD COLUMN would_go_back INTEGER DEFAULT 1;
    `,
  },
];
