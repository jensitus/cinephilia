namespace :maintenance do
  desc "Normalize movie IDs: merge duplicates and apply clean slugs. DRY_RUN=false to apply."
  task normalize_movie_ids: :environment do
    dry_run = ENV["DRY_RUN"] != "false"
    puts dry_run ? "DRY RUN — pass DRY_RUN=false to apply\n" : "APPLYING changes\n"

    groups = Movie.all.group_by { |m| Movie.create_movie_id(m.title) }

    collisions = groups.select { |_, movies| movies.size > 1 }
    singles    = groups.select { |_, movies| movies.size == 1 }

    if collisions.any?
      puts "=== #{collisions.size} collision group(s) ===\n\n"
      collisions.each do |new_id, movies|
        puts "  new id: #{new_id}"
        movies.each do |m|
          puts "    [#{m.id}] #{m.movie_id.ljust(45)} tmdb:#{m.tmdb_id.to_s.ljust(8)} schedules:#{m.schedules.count}"
        end

        next if dry_run

        winner, *losers = movies.sort_by { |m| [ m.tmdb_id.present? ? 0 : 1, -m.schedules.count ] }
        losers.each { |loser| merge_movies(winner, loser) }
        winner.update_column(:movie_id, new_id)
        puts "    => kept [#{winner.id}], removed #{losers.map(&:id)}"
      end
    else
      puts "No collisions found.\n"
    end

    renames = singles.reject { |new_id, movies| movies.first.movie_id == new_id }
    if renames.any?
      puts "\n=== #{renames.size} rename(s) ===\n\n"
      renames.each do |new_id, movies|
        m = movies.first
        puts "  #{m.movie_id} → #{new_id}"
        m.update_column(:movie_id, new_id) unless dry_run
      end
    else
      puts "\nNo renames needed.\n"
    end

    puts "\nDone (dry run — nothing changed)." if dry_run
  end

  def merge_movies(winner, loser)
    # Transfer schedules, skipping any that conflict with the winner's existing ones
    loser.schedules.each do |s|
      unless Schedule.exists?(movie_id: winner.id, cinema_id: s.cinema_id, time: s.time)
        s.update_column(:movie_id, winner.id)
      end
    end

    # Transfer genres not already on winner
    (loser.genres - winner.genres).each { |g| winner.genres << g }

    # Transfer credits not already on winner
    loser.credits.each do |c|
      unless Credit.exists?(movie_id: winner.id, person_id: c.person_id, role: c.role, job: c.job, character: c.character)
        c.update_column(:movie_id, winner.id)
      end
    end

    # Fill in any blank fields on winner from loser
    %i[description tmdb_id poster_path original_title year countries source_url].each do |attr|
      winner.send(:"#{attr}=", loser.send(attr)) if winner.send(attr).blank? && loser.send(attr).present?
    end
    winner.save if winner.changed?

    loser.destroy
  end
end
