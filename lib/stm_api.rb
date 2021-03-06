require 'stm_api/version'
require 'rest-client'
require 'base64'
require 'json'
require 'uri'

module StmApi
  # Your code goes here...
  class Donation
    attr_accessor :userhash
    attr_accessor :currency
    attr_accessor :team_id
    attr_accessor :campaign_id
    BEARER = 'LAXQszxcmpGMWi24y0NFt00YPWGJnJOo9Ba8ijLcI1fmiKHI1PDF7KG7PGJU7KcX'

    def initialize(params = {})
      @userhash = params[:userhash]
      @currency = params[:currency]
      @team_id = params[:team_id]
      @campaign_id = campaigns.first unless params[:campaign_id]
    end

    def user_info
      user_info_response = RestClient.get("https://api.sharethemeal.org/api/users/#{@userhash}",
                                          content_type: :json, accept: :json,
                                          Authorization: "Bearer #{BEARER}")
      user_info_json = JSON.parse(user_info_response)
      return user_info_json
    end

    def statistics
      user_info_response = RestClient.get("https://api.sharethemeal.org/api/campaigns/zomba/status",
                                          content_type: :json, accept: :json,
                                          Authorization: "Bearer #{BEARER}")
      user_info_json = JSON.parse(user_info_response)
      return user_info_json
    end

    def user_teams
      team_statistic = RestClient.get("https://api.sharethemeal.org/api/users/#{@userhash}/teams",
                                      content_type: :json, accept: :json,
                                      Authorization: "Bearer #{BEARER}")
      team_statistic_json = JSON.parse(team_statistic)

      team_statistic_json["userTeams"]
    end

    def campaigns
      campaigns_raw = RestClient.get("https://api.sharethemeal.org/api/meta",
                                     content_type: :json, accept: :json,
                                     Authorization: "Bearer #{BEARER}")
      campaigns_json = JSON.parse(campaigns_raw)
      found_campaigns = []
      campaigns_json["campaigns"].each do |camp, v|
        found_campaigns << camp
      end
      found_campaigns
    end

    def find_one_team(id)
      teams = user_teams
      teams.each do |t|
        if t["teamId"] == id
          return t
        end
      end
      return false
    end

    def donate(params = {})
      token_payload = {
        'userHash' => @userhash,
        'currency' => @currency
      }

      client_token = RestClient.post('https://api.sharethemeal.org/api/payment/braintree/client-tokens', token_payload.to_json,
                                     content_type: :json, accept: :json,
                                     Authorization: "Bearer #{BEARER}")

      client_token_response = JSON.parse(client_token)

      auth_reply = JSON.parse(Base64.decode64(client_token_response['clientToken']))
      finger_print =  URI.encode_www_form_component(auth_reply['authorizationFingerprint'])

      payment_infos = RestClient.get("https://api.braintreegateway.com/merchants/#{auth_reply['merchantId']}/client_api/v1/payment_methods?sharedCustomerIdentifierType=undefined&braintreeLibraryVersion=braintree%2Fweb%2F2.15.5&merchantAccountId=#{auth_reply['merchantAccountId']}&authorizationFingerprint=#{finger_print}&callback=")
      payment_infos_json = JSON.parse(payment_infos)

      transaction_payload = {
        'userHash' => @userhash,
        'amount' => params[:amount],
        'currency' => @currency,
        'paymentMethodNonce' => payment_infos_json['paymentMethods'].first['nonce'],
        'teamId' => @team_id,
        'campaignId' => @campaign_id
      }

      transaction_response = RestClient.post('https://api.sharethemeal.org/api/payment/braintree/transactions', transaction_payload.to_json, content_type: :json, accept: :json,
                                                                                                                                             'Authorization' => "Bearer #{BEARER}")

      transaction_response_json = JSON.parse(transaction_response)
      if transaction_response_json['result']['donationCreated'] == true
        return true
      else
        return false
      end

      # rescue
      #  return false
    end
  end
end
