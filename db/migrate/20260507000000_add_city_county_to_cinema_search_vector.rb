class AddCityCountyToCinemaSearchVector < ActiveRecord::Migration[8.0]
  def up
    execute "DROP TRIGGER IF EXISTS cinemas_search_vector_update ON cinemas"

    execute <<-SQL
      CREATE TRIGGER cinemas_search_vector_update BEFORE INSERT OR UPDATE
      ON cinemas FOR EACH ROW EXECUTE FUNCTION
      tsvector_update_trigger(
        search_vector, 'pg_catalog.german', title, city, county
      );
    SQL

    execute <<-SQL
      UPDATE cinemas SET search_vector =
        to_tsvector('german',
          coalesce(title, '') || ' ' ||
          coalesce(city, '') || ' ' ||
          coalesce(county, '')
        );
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS cinemas_search_vector_update ON cinemas"

    execute <<-SQL
      CREATE TRIGGER cinemas_search_vector_update BEFORE INSERT OR UPDATE
      ON cinemas FOR EACH ROW EXECUTE FUNCTION
      tsvector_update_trigger(
        search_vector, 'pg_catalog.german', title
      );
    SQL

    execute <<-SQL
      UPDATE cinemas SET search_vector =
        to_tsvector('german', coalesce(title, ''));
    SQL
  end
end
