require 'securerandom'
require 'digest/sha1'
require_relative 'logging'

class IncomingHandler

    include Logging

    HELP_PAGE = 'http://www.google.com'

    def initialize(db)
        @db = db
    end

    def handle(username, user_type, message)
        message = strip_names(message).strip
        puts "Handle #{username} (#{user_type}): #{message}"

        case message
        when /\A(?:send|give|tell)(?: me)?(?: my)?(?: submission)? code\z/i
            register_user(username, user_type)
        when /\Asubmit ([\-_a-zA-Z0-9]+) ([a-zA-Z0-9]+)\z/i
            submit_answer(username, user_type, $1, $2)
        when /\A(?:send|give|tell)(?: me)?(?: a)? secret\z/i
            get_secret(username, user_type)
        when /\Ado you have stairs in your house?\z/i
            @db.queue_dm(username, user_type, 'i am protected.')
        when /\Ai am protected\.?\z/i
            @db.queue_dm(username, user_type, 'the internet makes you stupid. :D')
        when /\Ahelp(?: me)?\z/
            get_help(username, user_type)
        end
    end

private

    def register_user(username, user_type)
        code = @db.get_code(username, user_type)
        if code.nil?
            code = generate_code
            @db.register_user(username, user_type, code)
        end

        @db.queue_dm(username, user_type, "your submission code is #{code}")
    end

    def submit_answer(username, user_type, challenge_name, hash)
        challenge = @db.get_challenge(challenge_name)
        if challenge.nil?
            msg = "invalid challenge: #{challenge_name}"[0..140]
            @db.queue_dm(username, user_type, msg)
            return
        end

        if challenge[:date_begin] > Date.today
            @db.queue_dm(username, user_type, "not started #{challenge_name}")
            return
        end

        user = @db.get_user(username, user_type)
        if user.nil?
            register_user(username, user_type)
            user = @db.get_user(username, user_type)
        end

        is_correct = check_submission(user[:code], challenge[:solution], hash)
        @db.add_or_update_submission(user[:id], challenge[:id], is_correct, hash)

        if challenge[:date_end] <= Date.today
            msg = "#{challenge_name} submission is #{is_correct ? 'CORRECT' : 'incorrect'}"
        else
            msg = "#{challenge_name} answer recieved. challenge ends #{challenge[:date_end]}"
        end

        @db.queue_dm(username, user_type, msg)
    end

    def get_secret(username, user_type)
        secret = @db.get_secret
        @db.queue_dm(username, user_type, secret) if secret
    end

    def get_help(username, user_type)
        help = "commands i understand are listed here: #{HELP_PAGE}"
        @db.queue_dm(username, uesr_type, help)
    end

    def strip_names(message)
        message.gsub(/@[^ ]+ /, '')
    end

    def generate_code
        random_string = SecureRandom.hex
    end

    def check_submission(code, solution, hash)
        correct = Digest::SHA1.hexdigest("#{solution}#{code}")
        correct.eql?(hash)
    end

end

#require_relative 'db'
#db = DB.new
#h = IncomingHandler.new(db)
#h.handle('caleb_fenton', 'twitter', 'give me my code')
#h.handle('caleb_fenton', 'twitter', 'send me a secret')
#h.handle('caleb_fenton', 'twitter', 'submit challenge1 864bcc000d5a158b81d63fc5233813bdc0f53a3c')
#h.handle('caleb_fenton', 'twitter', 'submit challenge2 864bcc000d5a158b81d63fc5233813bdc0f53a3c')
#h.handle('caleb_fenton', 'twitter', 'submit challenge3 864bcc000d5a158b81d63fc5233813bdc0f53a3c')
#h.handle('caleb_fenton', 'twitter', 'submit notexist 864bcc000d5a158b81d63fc5233813bdc0f53a3c')
# echo -n "There is no spoon.16fb58474b8fbdb2ed56c58d326f9334" | openssl sha1
