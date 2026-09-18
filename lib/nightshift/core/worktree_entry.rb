# frozen_string_literal: true
# typed: true

module Nightshift
  module Core
    #
    # WorktreeEntry — one line of `git worktree list --porcelain`
    #
    # Deliberately lossless: unlike Worktree.list, it keeps the worktrees whose
    # directory has disappeared, the detached ones and the locked ones. Those
    # are exactly the entries the doctor needs to see.
    #
    class WorktreeEntry < T::Struct
      extend T::Sig

      const :path, String
      const :head, T.nilable(String), default: nil
      const :branch, T.nilable(String), default: nil
      const :detached, T::Boolean, default: false
      const :locked, T::Boolean, default: false
      const :lock_reason, T.nilable(String), default: nil
      const :prunable, T::Boolean, default: false
      const :bare, T::Boolean, default: false

      sig { returns(T::Boolean) }
      def exists? = Dir.exist?(path)

      sig { returns(String) }
      def name = File.basename(path)

      sig { returns(String) }
      def label = branch || (head ? "(detached #{head[0, 8]})" : name)

      # Parse the whole porcelain output. Records are blank-line separated.
      sig { params(output: String).returns(T::Array[WorktreeEntry]) }
      def self.parse(output)
        output.split(/\n{2,}/).filter_map do |record|
          fields = { detached: false, locked: false, prunable: false, bare: false }
          record.each_line do |line|
            key, _, value = line.strip.partition(' ')
            case key
            when 'worktree' then fields[:path] = value
            when 'HEAD'     then fields[:head] = value
            when 'branch'   then fields[:branch] = value.sub(%r{\Arefs/heads/}, '')
            when 'detached' then fields[:detached] = true
            when 'bare'     then fields[:bare] = true
            when 'locked'
              fields[:locked] = true
              fields[:lock_reason] = value.empty? ? nil : value
            when 'prunable'
              fields[:prunable] = true
            end
          end
          fields[:path] ? new(**fields) : nil
        end
      end
    end
  end
end
