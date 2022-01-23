        -- Part II: Create the DDL for Your New Schema 

-- a. Allow new Users to Register 
-- Satisfies Part 1: #3 and #4 

CREATE TABLE "users" (
    "user_id" SERIAL PRIMARY KEY,
    "username" VARCHAR(25) UNIQUE NOT NULL, 
    "last_login" TIMESTAMP, 
    CONSTRAINT "unique_username" UNIQUE ("username"),
    CONSTRAINT "non_null_username" CHECK (LENGTH(TRIM("username")) > 0 )
); 

CREATE INDEX ON "users"("username");

-- b. Allow registered users to create new topics: 
-- Satisfies Part 1: #7 

CREATE TABLE "topics" ( 
    "topic_id" SERIAL PRIMARY KEY,
    "topic_name" VARCHAR(30) NOT NULL,
    "topic_description" VARCHAR(500),
    CONSTRAINT "unique_topics" UNIQUE (topic_name),
    CONSTRAINT "non_null_topic" CHECK (LENGTH(TRIM("topic_name")) > 0 )
);

CREATE INDEX ON "topics"("topic_name");
-- c. Allow registered users to create new posts on existing topics  
-- Satisfies Part 1: #2, #4, #6, and #7 

CREATE TABLE "posts" (
    "post_id" SERIAL PRIMARY KEY,
    "post_title" VARCHAR(100) NOT NULL,
    "posted_on" TIMESTAMP,
    "topic_id" INTEGER REFERENCES "topics"("topic_id") ON DELETE CASCADE,
    "user_id" INTEGER REFERENCES "users"("user_id") ON DELETE SET NULL,
    "url" VARCHAR(2050),
    "post_text" VARCHAR(60000), 
    CONSTRAINT "non_null_title" CHECK (LENGTH(TRIM("post_title")) > 0 ), 
    CONSTRAINT "url_or_text_content" CHECK ( 
        ((LENGTH(TRIM("url")) > 0)  AND (LENGTH(TRIM("post_text")) = 0 )) OR 
        ((LENGTH(TRIM("url")) = 0) AND (LENGTH(TRIM("post_text")) > 0 ))
    )
);

CREATE INDEX ON "posts"("url");


-- d. Allow registered users to comment on existing posts  
-- Satisfies Part 1: #6 and #7 

CREATE TABLE "comments" ( 
    "comment_id" SERIAL PRIMARY KEY,
    "comment_text" VARCHAR(8000) NOT NULL, 
    "commented_on" TIMESTAMP,
    "post_id" INTEGER REFERENCES "posts"("post_id") ON DELETE CASCADE,
    "user_id" INTEGER REFERENCES "users"("user_id") ON DELETE SET NULL,
    "comment_id_parent" INTEGER REFERENCES "comments"("comment_id") ON DELETE CASCADE,
    CONSTRAINT "non_null_text" CHECK (LENGTH(TRIM("comment_text")) > 0 )
);


-- e. Make sure that a given user can only vote once on a given post 
-- Satisfies Part 1: #1 and #5 

CREATE TABLE "votes" (
    "vote_id" SERIAL PRIMARY KEY,
    "vote" INTEGER NOT NULL,  
    "post_id" INTEGER REFERENCES "posts"("post_id") ON DELETE CASCADE,
    "user_id" INTEGER REFERENCES "users"("user_id") ON DELETE SET NULL, 
    CONSTRAINT "upvote_or_downvote" CHECK ("vote" = 1 or "vote" = -1), 
    CONSTRAINT "limit_one_vote" UNIQUE ("user_id", "post_id")
);


         
         -- Part III: Migrate the Provided Data

-- Migrate users info from bad_posts & bad_comments into the Users table

INSERT INTO "users"("username")
    SELECT DISTINCT "username"
    FROM "bad_posts"
    UNION
    SELECT DISTINCT "username"
    FROM "bad_comments"
    UNION 
    SELECT DISTINCT regexp_split_to_table("upvotes", ',')
    FROM "bad_posts"
    UNION 
    SELECT DISTINCT regexp_split_to_table("downvotes", ',')
    FROM "bad_posts";


-- Migrate Topic Info from bad_posts into the Topics table
INSERT INTO "topics"("topic_name")
    SELECT DISTINCT "topic"
    FROM "bad_posts";


-- Migrate posts info from bad_posts to Posts table
INSERT INTO "posts"(
    "post_title",
    "topic_id",
    "user_id",
    "url",
    "post_text" 
)

SELECT SUBSTRING("bad_posts"."title", 1, 100),
    "topics"."topic_id",
    "users"."user_id",
    "bad_posts"."url", 
    "bad_posts"."text_content" 
FROM "bad_posts"
JOIN "topics"
ON "bad_posts"."topic" = "topics"."topic_name"
JOIN "users" 
ON "bad_posts"."username" = "users"."username";


-- Migrate upvotes from bad_posts to Votes table

INSERT INTO "votes" ( 
    "post_id",
    "user_id", 
    "vote"
)

SELECT "bp_up"."id", "users"."user_id", 1 AS "upvote"
FROM( 
    SELECT "id", REGEXP_SPLIT_TO_TABLE("upvotes", ',') AS "upvotes"
    FROM "bad_posts") AS "bp_up"
JOIN "users"
ON "bp_up"."upvotes" = "users"."username";


-- Migrate downvote from bad_posts to Votes table

INSERT INTO "votes" (
    "post_id",
    "user_id", 
    "vote"
)

SELECT "bp_down"."id", "users"."user_id", -1 AS "downvote"
FROM (
    SELECT "id", REGEXP_SPLIT_TO_TABLE("downvotes", ',') AS "downvotes"
    FROM "bad_posts") AS "bp_down"
JOIN "users"
ON "bp_down"."downvotes" = "users"."username";


-- Migrate comments from bad_comments to Comments table

INSERT INTO "comments"(
    "post_id", 
    "user_id", 
    "comment_text"
)

SELECT "posts"."post_id", "users"."user_id", "bad_comments"."text_content"
FROM "bad_comments"
JOIN "posts" 
ON "bad_comments"."post_id" = "posts"."post_id"
JOIN "users"
ON "bad_comments"."username" = "users"."username";

