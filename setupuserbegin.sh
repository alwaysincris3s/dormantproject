for user in user1 user2 user3 user4 user5; do
  sudo useradd -m -s /bin/bash "$user"
  echo "$user:Password123" | sudo chpasswd
done
