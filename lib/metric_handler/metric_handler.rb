require 'socket'
require 'fog'
require 'eventmachine'
require 'json'
require "net/http"
require "uri"

module MetricHandler

  class MetricHandler

    def initialize
      @host, @port, @threadpool_size = "0.0.0.0", 9732, 100
    end

    def configure(host: "0.0.0.0", port: 9732, threadpool_size: 100)
      @host, @port, @threadpool_size = host, port, threadpool_size
    end

    def run
      EM.threadpool_size = @threadpool_size
      EM.run do
        warmup_threads = proc do
          i = 0
          i += 1
        end
        EM.defer(warmup_threads)

        config = YAML.load_file("queue.yaml")

        sqs = Fog::AWS::SQS.new(
         :aws_access_key_id => config['access_key'],
         :aws_secret_access_key => config['secret_key'],
         :region => config['queue_region']
        )
        loop do
          response = sqs.receive_message(config['queue_url'])
          messages = response.body['Message']
          if messages.empty? 
            sleep 2
          else
            messages.each do |m|
              operation = proc do
                response_body = JSON.parse(m['Body'])
                payload = response_body["payload"]
                session_id = payload["session_id"]
                user_id = payload["user_id"]
                premium = payload["premium"]

                metrics = {
                  anon: 0,
                  normal: 0,
                  premium: 0
               }

                post('/events', payload.to_json)
                post('/metrics/traffic', metrics.to_json)

                puts payload

                sqs.delete_message(config['queue_url'], m['ReceiptHandle'])
              end
              EM.defer(operation)
            end
          end
        end
      end
    end

    def post(path, body)
      http = Net::HTTP.new("dashboard.meducation.net")

      response = http.post(path, body)
      if response.code != '200'
        puts path
        puts response
      end
    end

  end
end


