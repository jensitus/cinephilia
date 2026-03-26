module Tmdb
  class Client
    BASE_URL = "https://api.themoviedb.org/3".freeze
    SEARCH_MOVIE_ENDPOINT = "#{BASE_URL}/search/movie".freeze
    MOVIE_ENDPOINT = "#{BASE_URL}/movie".freeze
    LANGUAGE_REGION = "language=de-DE&region=DE".freeze

    class << self
      def search_movies(query)
        url = build_search_url(query)
        fetch(url)
      end

      def get_movie(tmdb_id, with_language: true)
        url = build_movie_url(tmdb_id, with_language: with_language)
        fetch(url)
      end

      def get_credits(tmdb_id)
        url = UriService.call("#{MOVIE_ENDPOINT}/#{tmdb_id}/credits")
        fetch(url)
      end

      def search_person(name)
        url = UriService.call("#{BASE_URL}/search/person?query=#{URI.encode_www_form_component(name)}&#{LANGUAGE_REGION}")
        fetch(url)
      end

      def get_person_movie_credits(person_id)
        url = UriService.call("#{BASE_URL}/person/#{person_id}/movie_credits?#{LANGUAGE_REGION}")
        fetch(url)
      end

      def build_search_url(query)
        normalized_query = NormalizeAndCleanService.call(query)
        UriService.call("#{SEARCH_MOVIE_ENDPOINT}?query=#{normalized_query}&#{LANGUAGE_REGION}")
      end

      def build_movie_url(tmdb_id, with_language: true)
        if with_language
          UriService.call("#{MOVIE_ENDPOINT}/#{tmdb_id}?#{LANGUAGE_REGION}")
        else
          UriService.call("#{MOVIE_ENDPOINT}/#{tmdb_id}")
        end
      end

      private

      def fetch(url)
        TmdbResultService.call(url)
      end
    end
  end
end
