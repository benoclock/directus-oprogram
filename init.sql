-- Deploy o-program:init to pg

BEGIN;


CREATE DOMAIN "posint" AS int
	CHECK (VALUE >= 0);

CREATE DOMAIN "url" AS text
	CHECK ((VALUE ~ '^http(s)?:\/\/?[\w.-]+?(?:\.[\w\.-]+)+[\w\-\._~:/?#[\]@!\$&''\(\)\*\+,;=.]+'));


/*******************************
*       TYPE DE FORMATION
********************************/
CREATE TABLE "training_type" (
    "id" int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "label" text NOT NULL,
    "created_at" timestamptz NOT NULL DEFAULT now(),
    "updated_at" timestamptz,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_training_type" ON "training_type" ("label", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

/*******************************
*           FORMATION
********************************/
CREATE TABLE "training" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- Code interne à O'clock de formation
    "code" text NOT NULL,
    "name" text NOT NULL,
    -- Présentation apprenants
    "information" text,
    -- Explicatif formateur
    "description" text,
    -- Pour la communication
    "marketing" text,
    -- Score de priorité pour définir l'ordre par défaut des formations dans planifback
    "priority" int NOT NULL DEFAULT 1,
    -- Possibilité d'activer ou non une formation
    "active" boolean NOT NULL DEFAULT false,
    "activated_at" timestamptz,
    "training_type_id" int REFERENCES "training_type" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz,
    "deleted_at" timestamptz
);

COMMENT ON COLUMN "training"."code" IS 'Code interne à O''clock de formation';
COMMENT ON COLUMN "training"."information" IS 'Présentation apprenants';
COMMENT ON COLUMN "training"."description" IS 'Explicatif formateur';
COMMENT ON COLUMN "training"."marketing" IS 'Pour la communication';
COMMENT ON COLUMN "training"."priority" IS 'Score de priorité pour définir l''ordre par défaut des formations dans planifback';
COMMENT ON COLUMN "training"."active" IS 'Possibilité d''activer ou non une formation';

CREATE UNIQUE INDEX "unique_training_code" ON "training" ("code", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;
CREATE UNIQUE INDEX "unique_training_name" ON "training" ("name", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

/*******************************
*            TRAME
********************************/
CREATE TABLE "version" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- Numéro de version de la trame
    "number" text NOT NULL,
    -- défini la trame courante qui sera utilisé lors de la prochaine formation de promo
    "active" boolean DEFAULT false,
    -- Suivi de l'activation
    "activated_at" timestamptz,
    "training_id" integer NOT NULL REFERENCES "training"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz,
    "deleted_at" timestamptz
);

CREATE UNIQUE INDEX "unique_version" ON "version" ("number", "training_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

/*******************************
*             BLOC
********************************/
-- Nouvelle granularité dans l'organisation des formations, un bloc contient plusieurs saisons
CREATE TABLE "block" (
    "id" integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "name" text NOT NULL,
    -- Présentation apprenants
    "information" text,
    -- Explicatif formateur
    "description" text,
    -- Pour la communication
    "marketing" text,
    "version_id" integer REFERENCES "version" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz NOT NULL DEFAULT now(),
    "updated_at" timestamptz,
    "deleted_at" timestamptz
);

CREATE UNIQUE INDEX "unique_block" ON "block" ("name", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

/*******************************
*             SAISON
********************************/
CREATE TABLE "season" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "number" posint NOT NULL,
    "title" text NOT NULL,
    -- Présentation apprenants
    "information" text,
    -- Explicatif formateur
    "description" text,
    -- Pour la communication
    "marketing" text,
    "block_id" integer NOT NULL REFERENCES "block"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz,
    "deleted_at" timestamptz
);

CREATE UNIQUE INDEX "unique_season" ON "season" ("title", "block_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

/*******************************
*            EPISODE
********************************/
CREATE TABLE "episode" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "number" posint NOT NULL,
    "title" text NOT NULL,
    -- Présentation apprenants
    "information" text,
    -- Explicatif formateur
    "description" text,
    -- Pour la communication
    "marketing" text,
    "available_time" interval DEFAULT '05:00:00'::interval NOT NULL,
    "season_id" integer NOT NULL REFERENCES "season"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz,
    "deleted_at" timestamptz
);

CREATE UNIQUE INDEX "unique_episode" ON "episode" ("number", "title", "season_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

/*******************************
*        TYPE DE SEQUENCE
********************************/
CREATE TABLE "sequence_type" (
    "id" int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "label" text NOT NULL,
    -- Présentation apprenants
    "information" text,
    -- Explicatif formateur
    "description" text,
    -- Pour la communication
    "marketing" text,
    -- Cette séquence se passera-t-elle en cockpit ? (synchrone)
    "cockpit" boolean,
    "created_at" timestamptz NOT NULL DEFAULT now(),
    "updated_at" timestamptz,
    "deleted_at" timestamptz
);

CREATE UNIQUE INDEX "unique_sequence_type" ON "sequence_type" ("label", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

/*******************************
*          SEQUENCE
********************************/
CREATE TABLE "sequence" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "title" text NOT NULL,
    -- Présentation apprenants
    "information" text,
    -- Explicatif formateur
    "description" text,
    -- Pour la communication
    "marketing" text,
    -- Déroulé de la séquence pour aider le formateur
    "wiki" text,
    -- Position de la sequence au sein d'un l'épisode
    "position" integer DEFAULT 0 NOT NULL,
    -- temps estimé de la durée de la sequence
    "estimated_time" interval NOT NULL,
    -- cette séquence a-t-elle besoin dun tuteur ?
    "helper" boolean DEFAULT false NOT NULL,
    -- récapitulatif à destination des apprenants en fin d'épisode
    "summary" text,
    -- URL du support
    "url" url,
    -- Niveau de difficulté
    "level" integer,
    -- Type de séquence
    "sequence_type_id" integer REFERENCES "sequence_type" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    -- La séquence auquelle cette séquence fait référence
    "sequence_id" integer REFERENCES "sequence"("id") ON DELETE SET NULL ON UPDATE CASCADE,
    "episode_id" integer NOT NULL REFERENCES "episode"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz,
    "deleted_at" timestamptz
);

CREATE UNIQUE INDEX "unique_sequence" ON "sequence" ("title", "episode_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

/*******************************
*        DIPLOMES/TITRES
********************************/
CREATE TABLE "degree" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "name" text NOT NULL,
    "acronym" text NOT NULL,
    -- Présentation apprenants
    "information" text,
    -- Explicatif formateur
    "description" text,
    -- Pour la communication
    "marketing" text,
    -- Niveau d'étude (Bac+2, Bac+3…)
    "level" text NOT NULL,
    -- Est-ce un titre/diplome reconnu par l'état
    "official" boolean NOT NULL,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_degree" ON "degree" ("name", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

/*******************************
*   CATÉGORIES DE COMPÉTENCES
********************************/
CREATE TABLE "skill_category" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- Présentation apprenants
    "information" text,
    -- Explicatif formateur
    "description" text,
    "degree_id" integer NOT NULL REFERENCES "degree"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz,
    "deleted_at" timestamptz
);

/*******************************
*    OBJECTIF PEDAGOGIQUE
********************************/
CREATE TABLE "goal" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- objectif en lui-même
    "target" text NOT NULL,
    -- Moyens de vérification
    "medium" text NOT NULL,
    -- Moyens d'évaluation des apprenants
    "evaluation" text NOT NULL,
    -- Objectif parent de cette objectif
    "goal_id" integer REFERENCES "goal"("id") ON DELETE SET NULL ON UPDATE CASCADE,
    "skill_category_id" integer REFERENCES "skill_category"("id") ON DELETE SET NULL ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz,
    "deleted_at" timestamptz
);

CREATE UNIQUE INDEX "unique_goal" ON "goal" ("target", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

/*******************************
*  FICHE OBJECTIF PEDAGOGIQUE
********************************/
CREATE TABLE "card" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- Raison pour laquelle on veut atteindre cet objectif
    "why" text NOT NULL,
    -- Comment atteindre l'objectif
    "how" text NOT NULL,
    -- Résumé de l'objectif
    "summary" text NOT NULL,
    -- Trame utilisant cette fiche
    "version_id" integer REFERENCES "version"("id") ON DELETE SET NULL ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz,
    "deleted_at" timestamptz
);

/*******************************
*           NOTION
********************************/
CREATE TABLE "notion" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "label" text NOT NULL,
    "description" text,
    "url" url,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_notion" ON "notion" ("label", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

/*******************************
*           COMPÉTENCES
********************************/
CREATE TABLE "skill" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "description" text,
    "skill_category_id" integer NOT NULL REFERENCES "skill_category"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "updated_at" timestamptz,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_skill" ON "skill" ("description", "skill_category_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;



/*******************************
*   ASSOCIATION MANY TO MANY
********************************/

/*******************************
*          NOTION <>
********************************/
CREATE TABLE "version_require_notion" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "version_id" integer NOT NULL REFERENCES "version"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "notion_id" integer NOT NULL REFERENCES "notion"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_version_require_notion" ON "version_require_notion" ("version_id", "notion_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

CREATE TABLE "block_require_notion" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "block_id" integer NOT NULL REFERENCES "block"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "notion_id" integer NOT NULL REFERENCES "notion"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_block_require_notion" ON "block_require_notion" ("block_id", "notion_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

CREATE TABLE "season_require_notion" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "season_id" integer NOT NULL REFERENCES "season"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "notion_id" integer NOT NULL REFERENCES "notion"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_season_require_notion" ON "season_require_notion" ("season_id", "notion_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

CREATE TABLE "episode_require_notion" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "episode_id" integer NOT NULL REFERENCES "episode"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "notion_id" integer NOT NULL REFERENCES "notion"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_episode_require_notion" ON "episode_require_notion" ("episode_id", "notion_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

CREATE TABLE "sequence_require_notion" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "sequence_id" integer NOT NULL REFERENCES "sequence"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "notion_id" integer NOT NULL REFERENCES "notion"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_sequence_require_notion" ON "sequence_require_notion" ("sequence_id", "notion_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

CREATE TABLE "sequence_touch_notion" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "sequence_id" integer NOT NULL REFERENCES "sequence"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "notion_id" integer NOT NULL REFERENCES "notion"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_sequence_touch_notion" ON "sequence_touch_notion" ("sequence_id", "notion_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

/*******************************
*           GOAL <>
********************************/
CREATE TABLE "season_touch_goal" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "season_id" integer NOT NULL REFERENCES "season"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "goal_id" integer NOT NULL REFERENCES "goal"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_season_touch_goal" ON "season_touch_goal" ("season_id", "goal_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

CREATE TABLE "episode_touch_goal" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "episode_id" integer NOT NULL REFERENCES "episode"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "goal_id" integer NOT NULL REFERENCES "goal"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_episode_touch_goal" ON "episode_touch_goal" ("episode_id", "goal_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

CREATE TABLE "sequence_touch_goal" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "sequence_id" integer NOT NULL REFERENCES "sequence"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "goal_id" integer NOT NULL REFERENCES "goal"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_sequence_touch_goal" ON "sequence_touch_goal" ("sequence_id", "goal_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

CREATE TABLE "sequence_check_goal" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "sequence_id" integer NOT NULL REFERENCES "sequence"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "goal_id" integer NOT NULL REFERENCES "goal"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_sequence_check_goal" ON "sequence_check_goal" ("sequence_id", "goal_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

CREATE TABLE "skill_validate_goal" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "skill_id" integer NOT NULL REFERENCES "skill"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "goal_id" integer NOT NULL REFERENCES "goal"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_skill_validate_goal" ON "skill_validate_goal" ("skill_id", "goal_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

CREATE TABLE "goal_has_card" (
    "id" integer NOT NULL GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    "goal_id" integer NOT NULL REFERENCES "goal"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "card_id" integer NOT NULL REFERENCES "card"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    "created_at" timestamptz DEFAULT now() NOT NULL,
    "deleted_at" timestamptz
);
CREATE UNIQUE INDEX "unique_goal_has_card" ON "goal_has_card" ("goal_id", "card_id", ("deleted_at" IS NULL)) WHERE "deleted_at" IS NULL;

COMMIT;
