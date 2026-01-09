class AddSearchVectors < ActiveRecord::Migration[8.0]
  def up
    # Add tsvector columns
    add_column :movies, :search_vector, :tsvector
    add_column :cinemas, :search_vector, :tsvector
    add_column :genres, :search_vector, :tsvector
    add_column :people, :search_vector, :tsvector

    # Add GIN indexes for fast searching
    add_index :movies, :search_vector, using: :gin
    add_index :cinemas, :search_vector, using: :gin
    add_index :genres, :search_vector, using: :gin
    add_index :people, :search_vector, using: :gin

    # Create triggers to automatically update search vectors
    execute <<-SQL
      -- German for movies (title and description)
      CREATE TRIGGER movies_search_vector_update BEFORE INSERT OR UPDATE
      ON movies FOR EACH ROW EXECUTE FUNCTION
      tsvector_update_trigger(
        search_vector, 'pg_catalog.german', title, description
      );

      -- German for cinemas (name)
      CREATE TRIGGER cinemas_search_vector_update BEFORE INSERT OR UPDATE
      ON cinemas FOR EACH ROW EXECUTE FUNCTION
      tsvector_update_trigger(
        search_vector, 'pg_catalog.german', title
      );

      -- German for genres (name)
      CREATE TRIGGER genres_search_vector_update BEFORE INSERT OR UPDATE
      ON genres FOR EACH ROW EXECUTE FUNCTION
      tsvector_update_trigger(
        search_vector, 'pg_catalog.german', name
      );

      -- English for people (name)
      CREATE TRIGGER people_search_vector_update BEFORE INSERT OR UPDATE
      ON people FOR EACH ROW EXECUTE FUNCTION
      tsvector_update_trigger(
        search_vector, 'pg_catalog.english', name
      );
    SQL

    # Populate existing data
    execute <<-SQL
      UPDATE movies SET search_vector =#{' '}
        to_tsvector('german', coalesce(title, '') || ' ' || coalesce(description, ''));

      UPDATE cinemas SET search_vector =#{' '}
        to_tsvector('german', coalesce(title, ''));

      UPDATE genres SET search_vector =#{' '}
        to_tsvector('german', coalesce(name, ''));

      UPDATE people SET search_vector =#{' '}
        to_tsvector('english', coalesce(name, ''));
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS movies_search_vector_update ON movies"
    execute "DROP TRIGGER IF EXISTS cinemas_search_vector_update ON cinemas"
    execute "DROP TRIGGER IF EXISTS genres_search_vector_update ON genres"
    execute "DROP TRIGGER IF EXISTS people_search_vector_update ON people"

    remove_index :movies, :search_vector
    remove_index :cinemas, :search_vector
    remove_index :genres, :search_vector
    remove_index :people, :search_vector

    remove_column :movies, :search_vector
    remove_column :cinemas, :search_vector
    remove_column :genres, :search_vector
    remove_column :people, :search_vector
  end
end
