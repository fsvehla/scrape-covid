# frozen_string_literal: true

require 'net/http'
require 'nokogiri'
require 'time'
require 'uri'

class Scraper
  URL = URI.parse('https://www.sozialministerium.at/Informationen-zum-Coronavirus/Neuartiges-Coronavirus-(2019-nCov).html')

  class << self
    # @return [Scraper]
    def instance
      @scraper ||= Scraper.new
    end
  end

  # @return [String]
  def scrape
    Nokogiri::HTML.parse(Net::HTTP.get(URL))
      .xpath('//meta[@name = "description"]')[0]
      .attributes['content']
      .text
  end
end

class SummaryFetcher
  # @param [Scraper] scraper
  def initialize(scraper, fd)
    @scraper = scraper
    @fd      = fd
  end

  def self.start(scraper, &block)
    File.open('last-summary.text', File::RDWR | File::CREAT, 0644) do |fd|
      block.call(SummaryFetcher.new(scraper, fd))
    end
  end

  def last
    @fd.flock(File::LOCK_EX)
    @fd.rewind
    read = @fd.read
    @fd.flock(File::LOCK_UN)

    read.chomp
  end

  def last=(line)
    @fd.flock(File::LOCK_EX)
    @fd.rewind
    @fd.write(line.chomp)
    @fd.flush
    @fd.flock(File::LOCK_UN)
  end

  def current
    @scraper.scrape
  end
end

SummaryFetcher.start(Scraper.new) do |fetcher|
  loop do
    n = fetcher.current
    l = fetcher.last

    if n != l
      fetcher.last = n

      message = Time.now.iso8601 + " -- new changes detected:\n--- #{ l.chomp }\n+++ " + n

      puts message
      system("terminal-notifier -ignoreDnD -title 'COVID-19 .at update' -message '#{ n }'")
    end

    Kernel.sleep 5 * 60 + (0.5 + rand)
  end
end
