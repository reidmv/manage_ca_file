#!/opt/puppetlabs/puppet/bin/ruby

require 'open3'
require 'openssl'

require_relative '../../ruby_task_helper/files/task_helper.rb'

# Example task that is based on the ruby_task_helper
class SyncCRLContent < TaskHelper
  def task(name: nil, **kwargs)
    crl_array = []

    # Read current ca_crl file
    local_crls_all = File.read('/etc/puppetlabs/puppet/ssl/ca/ca_crl.pem')

    # Split up certs
    delimeter = "\n-----END X509 CRL-----\n"

    local_crls_strings = local_crls_all.split(delimeter)

    # Get all certs as ruby CRL objects
    all_crls = local_crls_strings.map { |local_crl|
      next_crl = OpenSSL::X509::CRL.new("#{local_crl}\n-----END X509 CRL-----")
    }

    # Delete all CRLs that match the new CRL keyids coming in
    non_remote_crls = all_crls.select { |crl|
      authorityKeyIdentifier = crl.extensions().select { |extension| extension.to_s()[%r{(keyid.+),}] }
      keyid = %r{(keyid.+),}.match(authorityKeyIdentifier[0].to_s())[1]

      crl.to_text() unless kwargs[:remote_authority_key_identifiers].include? keyid
    }

    # Rebuild CRL and write it back
    new_crl = "#{kwargs[:remote_crl_content].strip()}\n#{non_remote_crls.join('')}"

    result = File.write('/etc/puppetlabs/puppet/ssl/ca/ca_crl.pem', new_crl)

    { crl: new_crl }
  end
end

SyncCRLContent.run if $PROGRAM_NAME == __FILE__