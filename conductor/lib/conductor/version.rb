# frozen_string_literal: true

require_relative "gem_version"

module Conductor
  # Returns the currently-loaded version of Conductor as a <tt>Gem::Version</tt>.
  def self.version
    gem_version
  end
end
