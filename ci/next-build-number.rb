#!/usr/bin/env ruby
# frozen_string_literal: true

# Prints the next free build number (CFBundleVersion) for an app on App Store Connect:
#   max(highest uploaded build + 1, project CURRENT_PROJECT_VERSION)
#
# Usage: next-build-number.rb <bundle-id> <project-build-number>
# Env:   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (path to the .p8 key)

require 'base64'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'

API = 'https://api.appstoreconnect.apple.com/v1'

def b64url(data)
  Base64.urlsafe_encode64(data, padding: false)
end

# ES256 JWT for the App Store Connect API (valid 10 minutes).
def jwt(key_id, issuer_id, key_pem)
  header = { alg: 'ES256', kid: key_id, typ: 'JWT' }
  now = Time.now.to_i
  payload = { iss: issuer_id, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' }
  signing_input = "#{b64url(header.to_json)}.#{b64url(payload.to_json)}"
  key = OpenSSL::PKey::EC.new(key_pem)
  der = key.sign(OpenSSL::Digest.new('SHA256'), signing_input)
  # JWS wants the raw 64-byte r||s, not the DER sequence OpenSSL returns.
  r, s = OpenSSL::ASN1.decode(der).value.map { |i| i.value.to_s(2).rjust(32, "\0") }
  "#{signing_input}.#{b64url(r + s)}"
end

def get(path, token)
  uri = URI("#{API}#{path}")
  req = Net::HTTP::Get.new(uri)
  req['Authorization'] = "Bearer #{token}"
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
  abort "App Store Connect API #{res.code} for #{uri.path}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
  JSON.parse(res.body)
end

def max_build_number(versions)
  versions.map { |v| Integer(v, exception: false) }.compact.max
end

def next_build_number(uploaded_max, project_build)
  uploaded_max.nil? ? project_build : [uploaded_max + 1, project_build].max
end

if $PROGRAM_NAME == __FILE__
  bundle_id, project_build = ARGV
  abort 'usage: next-build-number.rb <bundle-id> <project-build-number>' unless bundle_id && project_build
  project_build = Integer(project_build)

  token = jwt(ENV.fetch('ASC_KEY_ID'), ENV.fetch('ASC_ISSUER_ID'), File.read(ENV.fetch('ASC_KEY_PATH')))
  apps = get("/apps?filter[bundleId]=#{URI.encode_www_form_component(bundle_id)}&fields[apps]=bundleId", token)
  app = apps['data'].find { |a| a.dig('attributes', 'bundleId') == bundle_id }
  abort "No app with bundle id #{bundle_id} on App Store Connect" unless app

  # Newest uploads first; the highest build number is among them unless numbers went backwards.
  builds = get("/builds?filter[app]=#{app['id']}&sort=-uploadedDate&limit=200&fields[builds]=version", token)
  uploaded_max = max_build_number(builds['data'].map { |b| b.dig('attributes', 'version') })

  warn "Highest build on App Store Connect: #{uploaded_max || 'none'}; project: #{project_build}"
  puts next_build_number(uploaded_max, project_build)
end
