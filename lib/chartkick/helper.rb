module Chartkick
  module Helper
    def line_chart(data_source, **options)
      chartkick_chart "LineChart", data_source, **options
    end

    def pie_chart(data_source, **options)
      chartkick_chart "PieChart", data_source, **options
    end

    def column_chart(data_source, **options)
      chartkick_chart "ColumnChart", data_source, **options
    end

    def bar_chart(data_source, **options)
      chartkick_chart "BarChart", data_source, **options
    end

    def area_chart(data_source, **options)
      chartkick_chart "AreaChart", data_source, **options
    end

    def scatter_chart(data_source, **options)
      chartkick_chart "ScatterChart", data_source, **options
    end

    def geo_chart(data_source, **options)
      chartkick_chart "GeoChart", data_source, **options
    end

    def timeline(data_source, **options)
      chartkick_chart "Timeline", data_source, **options
    end

    private

    # don't break out options since need to merge with default options
    def chartkick_chart(klass, data_source, **options)
      options = Chartkick::Utils.deep_merge(Chartkick.options, options)

      @chartkick_chart_id ||= 0
      element_id = options.delete(:id) || "chart-#{@chartkick_chart_id += 1}"

      height = (options.delete(:height) || "300px").to_s
      width = (options.delete(:width) || "100%").to_s
      defer = !!options.delete(:defer)

      # content_for: nil must override default
      content_for = options.key?(:content_for) ? options.delete(:content_for) : Chartkick.content_for

      nonce = options.fetch(:nonce, true)
      options.delete(:nonce)
      if nonce == true
        # Secure Headers also defines content_security_policy_nonce but it takes an argument
        # Rails 5.2 overrides this method, but earlier versions do not
        if respond_to?(:content_security_policy_nonce) && (content_security_policy_nonce rescue nil)
          # Rails 5.2+
          nonce = content_security_policy_nonce
        elsif respond_to?(:content_security_policy_script_nonce)
          # Secure Headers
          nonce = content_security_policy_script_nonce
        else
          nonce = nil
        end
      end
      nonce_html = nonce ? " nonce=\"#{ERB::Util.html_escape(nonce)}\"" : nil

      # html vars
      html_vars = {
        id: element_id,
        height: height,
        width: width,
        # don't delete loading option since it needs to be passed to JS
        loading: options[:loading] || "Loading..."
      }

      [:height, :width].each do |k|
        # limit to alphanumeric and % for simplicity
        # this prevents things like calc() but safety is the priority
        # dot does not need escaped in square brackets
        raise ArgumentError, "Invalid #{k}" unless /\A[a-zA-Z0-9%.]*\z/.match?(html_vars[k])
      end

      html_vars.each_key do |k|
        # escape all variables
        # we already limit height and width above, but escape for safety as fail-safe
        # to prevent XSS injection in worse-case scenario
        html_vars[k] = ERB::Util.html_escape(html_vars[k])
      end

      html = (options.delete(:html) || %(<div id="%{id}" style="height: %{height}; width: %{width}; text-align: center; color: #999; line-height: %{height}; font-size: 14px; font-family: 'Lucida Grande', 'Lucida Sans Unicode', Verdana, Arial, Helvetica, sans-serif;">%{loading}</div>)) % html_vars

      # js vars
      js_vars = {
        type: klass.to_json,
        id: element_id.to_json,
        data: data_source.respond_to?(:chart_json) ? data_source.chart_json : data_source.to_json,
        options: options.to_json
      }
      js_vars.each_key do |k|
        js_vars[k] = Chartkick::Utils.json_escape(js_vars[k])
      end
      createjs = "new Chartkick[%{type}](%{id}, %{data}, %{options});" % js_vars

      warn "[chartkick] The defer option is no longer needed and can be removed" if defer

      # Turbolinks preview restores the DOM except for painted <canvas>
      # since it uses cloneNode(true) - https://developer.mozilla.org/en-US/docs/Web/API/Node/
      #
      # don't rerun JS on preview to prevent
      # 1. animation
      # 2. loading data from URL
      js = <<~JS
        <script#{nonce_html}>
          (function() {
            if (document.documentElement.hasAttribute("data-turbolinks-preview")) return;
            if (document.documentElement.hasAttribute("data-turbo-preview")) return;

            var createChart = function() { #{createjs} };
            if ("Chartkick" in window) {
              createChart();
            } else {
              window.addEventListener("chartkick:load", createChart, true);
            }
          })();
        </script>
      JS

      if content_for
        content_for(content_for) { js.respond_to?(:html_safe) ? js.html_safe : js }
      else
        html += "\n#{js}"
      end

      html.respond_to?(:html_safe) ? html.html_safe : html
    end
  end
end
