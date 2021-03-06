require 'faraday'
require 'json'

module FastlaneCore
  class CrashReporter
    class << self
      @did_report_crash = false

      @explitly_enabled_for_testing = false

      def crash_report_path
        File.join(FastlaneCore.fastlane_user_dir, 'latest_crash.json')
      end

      def enabled?
        !FastlaneCore::Env.truthy?("FASTLANE_OPT_OUT_CRASH_REPORTING")
      end

      def report_crash(type: :unknown, exception: nil, action: nil)
        return unless enabled?
        return if @did_report_crash

        # Do not run the crash reporter while tests are happening (it might try to send
        # a crash report), unless we have explictly turned on the crash reporter because
        # we want to test it
        return if Helper.test? && !@explitly_enabled_for_testing

        payload = CrashReportGenerator.generate(type: type, exception: exception, action: action)
        send_report(payload: payload)
        save_file(payload: payload)
        show_message unless did_show_message?
        @did_report_crash = true
      end

      def reset_crash_reporter_for_testing
        @did_report_crash = false
      end

      def enable_for_testing
        @explitly_enabled_for_testing = true
      end

      def disable_for_testing
        @explitly_enabled_for_testing = false
      end

      private

      def show_message
        UI.message("Sending crash report...")
        UI.message("The stacktrace is sanitized so no personal information is sent.")
        UI.message("To see what we are sending, look here: #{crash_report_path}")
        UI.message("Learn more at https://github.com/fastlane/fastlane#crash-reporting")
        UI.message("You can disable crash reporting by adding `opt_out_crash_reporting` at the top of your Fastfile")
      end

      def did_show_message?
        file_name = ".did_show_opt_out_crash_info"

        path = File.join(FastlaneCore.fastlane_user_dir, file_name)
        did_show = File.exist?(path)

        return did_show if did_show

        File.write(path, '1')
        false
      end

      def save_file(payload: "{}")
        File.write(crash_report_path, payload)
      rescue
        UI.message("fastlane failed to write the crash report to #{crash_report_path}.")
      end

      def send_report(payload: "{}")
        connection = Faraday.new(url: "https://clouderrorreporting.googleapis.com/v1beta1/projects/fastlane-166414/events:report?key=AIzaSyAMACPfuI-wi4grJWEZjcPvhfV2Rhmddwo")
        connection.post do |request|
          request.headers['Content-Type'] = 'application/json'
          request.body = payload
        end
      end
    end
  end
end
