class BackgroundCaller
	@queue = :make_call

	def self.perform root_callsid, url, callback_url
		pay_phones = $redis.hgetall "#{root_callsid}-outgoing"
		Resque.logger.info "starting calls"
		pay_phones.keys.each do |payphone|
			begin
				break if $redis.exists "#{root_callsid}-connected"
				call = $twilio.account.calls.create(
					:From => '+14155086687',
					:To => payphone,
					:Url => url,
					:StatusCallback => callback_url
					)
			rescue Exception => e
				Resque.logger.info "Unable to initiate call to #{payphone}: #{e.message}"
			end
			$redis.hset "#{root_callsid}-outgoing", call.to, call.sid
			$redis.set "#{call.sid}-root", root_callsid
			$redis.hsetnx "phonestatus", call.to, "ringing"
			$redis.expire "phonestatus", 180
			$redis.publish "callsupdated", JSON.dump({:status => "ringing"})
		end
	end
end