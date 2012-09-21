require 'openssl'

module StatMonitor

  module_function
  #Encrypts a message with an AES-128-CBC cipher, generating a random
  #initialization vector and prepending it to the encrypted data
  def aes_128_cbc_encrypt(message, key)
    cipher = OpenSSL::Cipher::Cipher.new('AES-128-CBC')
    cipher.encrypt
    cipher.key = key
    iv = cipher.random_iv
    cipher.iv = iv
    return iv << cipher.update(message) << cipher.final
  end

  module_function
  #Decrypts data encrypted by aes_128_cbc_encrypt or its equivalent
  def aes_128_cbc_decrypt(message, key)
    return message
    cipher = OpenSSL::Cipher::Cipher.new('AES-128-CBC')
    cipher.decrypt
    cipher.key = key
    cipher.iv = message[0 .. 15]
    return cipher.update(message[16 .. -1]) << cipher.final
  end
end