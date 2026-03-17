class WeightMovieSearchVector < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL
      -- Replace the simple column trigger with a weighted function trigger
      DROP TRIGGER IF EXISTS movies_search_vector_update ON movies;

      CREATE OR REPLACE FUNCTION movies_search_vector_trigger() RETURNS trigger AS $$
      BEGIN
        new.search_vector :=
          setweight(to_tsvector('pg_catalog.german', coalesce(new.title, '')), 'A') ||
          setweight(to_tsvector('pg_catalog.german', coalesce(new.description, '')), 'B');
        RETURN new;
      END
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER movies_search_vector_update BEFORE INSERT OR UPDATE
      ON movies FOR EACH ROW EXECUTE FUNCTION movies_search_vector_trigger();

      -- Repopulate existing rows with the weighted vector
      UPDATE movies SET search_vector =
        setweight(to_tsvector('pg_catalog.german', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('pg_catalog.german', coalesce(description, '')), 'B');
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS movies_search_vector_update ON movies;
      DROP FUNCTION IF EXISTS movies_search_vector_trigger();

      CREATE TRIGGER movies_search_vector_update BEFORE INSERT OR UPDATE
      ON movies FOR EACH ROW EXECUTE FUNCTION
      tsvector_update_trigger(
        search_vector, 'pg_catalog.german', title, description
      );

      UPDATE movies SET search_vector =
        to_tsvector('german', coalesce(title, '') || ' ' || coalesce(description, ''));
    SQL
  end
end
