class MainController < ApplicationController

  skip_before_action :verify_authenticity_token

  def raw_logs_data
    logs = Rails.cache.fetch('logs') || {}
    render :text => logs.to_json
  end

  def status
    render :text => "All is okay"
  end

  def data_input
    Rails.cache.write('updated_at', DateTime.now)

    logs = Rails.cache.read('logs') || {}
    logs[params[:env]] = request.body.read.encode('utf-8', :invalid => :replace, :undef => :replace, :replace => '_')

    Rails.cache.write('logs', logs)
    render text: "Got the data. Thanks"
  end

  def raw_logs
    Rails.cache.fetch('logs') || {}
  end

  def show
    updated_at = Rails.cache.read('updated_at')
    @last_updated = (DateTime.now.to_i - updated_at.to_i) / 60 if updated_at
    @results = {}

    raw_logs.each do |k,v|
      @results[k] = parse_commits("\n" + v)
    end

    @stats = {}
    @results.each do |key,v|
      commits = @results[key]
      @stats[key] = {stories: 0, bugs: 0}
      commits.each do |commit|
        if commit[:valid_story]
          commit[:rally_story] ? @stats[key][:stories] += 1  : @stats[key][:bugs] += 1
        end
      end
    end
  end

  def parse_commits(raw_commits)
    commits = raw_commits.split("\ncommit")
    total = []

    puts commits.size.inspect
    puts commits.last.inspect

    return [] if commits.last == "\n"

    commits.reject!(&:empty?).each_with_index do |item, index|
      commit = {}
      temp = item.split("\n")
      commit[:commit] = temp[0].strip
      commit[:commit_abrev] = temp[0][0...8].strip
      commit[:author] = temp[1].split(' ').last.strip.split('@').first[1...100].split('_').last
      date = temp[2].split('Date: ').last
      commit[:date] = date.strip.split(":").first[0...-2]
      commit[:raw] = item

      begin
        commit[:days_ago] =  (DateTime.now - DateTime.parse(date)).to_i
        details = temp[4]
        commit[:story] = details.split(':')[0].strip[0..10][1...-1]
        commit[:rally_story] = commit[:story][0...2] == 'US'
        commit[:valid_story] = commit[:story][0...2] == 'US' || commit[:story][0...2] == 'XF'
        commit[:key] = details.split(':')[1].split('-')[0].strip[0..22]
        commit[:description] = details.split(':')[1].split('-')[1].strip
        commit[:body] = temp[3..temp.size].join("\n").strip
      rescue
        commit[:description] = temp[4]
        commit[:body] = temp[3..temp.size].join("\n").strip[0..10]
      end

      total << commit
    end
    total
  end

end



