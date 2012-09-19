require 'openssl'

module StatMonitor
  def aes_128_cbc_encrypt(message, key)
    cipher = OpenSSL::Cipher::Cipher.new('AES-128-CBC')
    cipher.encrypt
    cipher.key = key
    cipher.iv = cipher.random_iv
    return cipher.update(message) << cipher.final
  end

  def aes_128_cbc_decrypt(message, key)
    cipher = OpenSSL::Cipher::Cipher.new('AES-128-CBC')
    cipher.decrypt
    cipher.key = key
    cipher.iv = cipher.random_iv
    return cipher.update(message) << cipher.final
  end
end