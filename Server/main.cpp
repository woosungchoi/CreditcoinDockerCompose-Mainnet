#include <iostream>
#include <thread>
#include <atomic>
#include <random>
#include <chrono>
#include <csignal>
#include <list>
#include <cryptopp/cryptlib.h>
#include <cryptopp/sha.h>
#include <boost/bind.hpp>
#include <boost/asio.hpp>
#include <boost/algorithm/string.hpp>

using boost::asio::ip::tcp;

static std::string port;

const std::string END_OF_STR("\n", 1);
auto const DELIM = boost::is_any_of(",");

std::string localAddress("172.17.0.1");

// command
const std::string WORK("WORK"); // new work
const std::string GET("GET");   // get the latest hash
const std::string HASH("HASH"); // hash found
const std::string STOP("STOP"); // hash worker stop
const std::string CLOSE("CLOSE");
const std::string SUCCESS("SUCCESS");
const std::string ERROR("ERROR");
const std::string EMPTY("EMPTY");

const unsigned int THREAD_COUNT = std::thread::hardware_concurrency();
std::atomic_ullong TIMESTAMP_ATOMIC(0);

std::string best_block_id(EMPTY);
std::string best_nonce;
int best_difficulty = -1;

class session;
std::list<session*> sessionList;

void register_session(session *s)
{
    sessionList.push_back(s);
}

void unregister_session(session *s)
{
    auto it = std::find(sessionList.begin(), sessionList.end(), s);
    if (it != sessionList.end())
    {
        sessionList.erase(it);
    }
}

class session
{
public:
    session(boost::asio::io_service &io_service)
        : socket_(io_service)
    {
    }

    tcp::socket &socket()
    {
        return socket_;
    }

    void close()
    {
        std::string body(CLOSE);
        boost::asio::write(socket_, boost::asio::buffer(body + END_OF_STR));
        socket_.close();
    }

    void start()
    {
        read();
    }

private:
    int count_leading_zeroes(std::string &digest)
    {
        int count = 0;

        for (int i = 0; i < digest.size(); i++)
        {
            byte b = static_cast<byte>(digest.data()[i]);

            if (b > 0)
            {
                if (b >= 128)
                {
                }
                else if (b >= 64)
                {
                    count = count + 1;
                }
                else if (b >= 32)
                {
                    count = count + 2;
                }
                else if (b >= 16)
                {
                    count = count + 3;
                }
                else if (b >= 8)
                {
                    count = count + 4;
                }
                else if (b >= 4)
                {
                    count = count + 5;
                }
                else if (b >= 2)
                {
                    count = count + 6;
                }
                else
                {
                    count = count + 7;
                }
                break;
            }
            else
            {
                count = count + 8;
            }
        }

        return count;
    }

    unsigned long long random_nonce()
    {
        std::random_device random_device;
        std::mt19937 generator(random_device());

        std::uniform_int_distribution<unsigned long long> random_distribution(
            std::numeric_limits<unsigned long long>::min(),
            std::numeric_limits<unsigned long long>::max() / 2);

        unsigned long long nonce = random_distribution(generator);

        return nonce;
    }

    void hash_worker_handler(unsigned int i, std::string block_id, std::string public_key, std::string str_difficulty, unsigned long long timestamp)
    {
        try
        {
            boost::asio::io_service io_service;
            tcp::resolver resolver(io_service);
            tcp::resolver::query query(tcp::v4(), localAddress, port);
            tcp::resolver::iterator iterator = resolver.resolve(query);

            tcp::socket s(io_service);
            boost::asio::connect(s, iterator);

            CryptoPP::SHA256 hash;

            unsigned long long nonce = random_nonce();
            int difficulty = std::stoi(str_difficulty);

            while (1)
            {
                if (TIMESTAMP_ATOMIC.load() != timestamp)
                {
                    break;
                }

                std::string digest;
                std::string str_nonce = std::to_string(nonce);

                // SHA256 Hashing!!!
                hash.Update((const byte *)block_id.data(), block_id.size());
                hash.Update((const byte *)public_key.data(), public_key.size());
                hash.Update((const byte *)str_nonce.data(), str_nonce.size());
                digest.resize(hash.DigestSize());
                hash.Final((byte *)&digest[0]);
                // SHA256 Hashing!!!

                int digest_difficulty = count_leading_zeroes(digest);

                if (digest_difficulty >= difficulty)
                {
                    // hash send
                    std::string body;
                    body.reserve(256);
                    body.append(HASH);
                    body.append(",");
                    body.append(block_id);
                    body.append(",");
                    body.append(std::to_string(digest_difficulty));
                    body.append(",");
                    body.append(std::to_string(nonce));
                    body.append(END_OF_STR);

                    boost::asio::write(s, boost::asio::buffer(body));
                    boost::asio::streambuf read_buffer;
                    boost::asio::read_until(s, read_buffer, END_OF_STR);

                    std::string response;
                    std::istream is(&read_buffer);
                    std::getline(is, response);

                    if (response == STOP)
                    {
                        break;
                    }

                    difficulty = digest_difficulty + 1;
                    nonce = random_nonce();
                }
                else
                {
                    nonce = nonce + 1;
                }
            }
        }
        catch (std::exception &e)
        {
            std::cerr << "Exception: " << e.what() << "\n";
        }
    }

    unsigned long long time_stamp()
    {
        std::chrono::system_clock::time_point time_point = std::chrono::system_clock::now();
        std::chrono::system_clock::duration duration = time_point.time_since_epoch();
        unsigned long long timestamp = duration.count();
        return timestamp;
    }

    void hash_worker_stop()
    {
        best_difficulty = -1;
        TIMESTAMP_ATOMIC.store(time_stamp());
    }

    void hash_worker_start(std::string &block_id, std::string &public_key, std::string &difficulty)
    {
        best_block_id = block_id;

        unsigned long long timestamp = TIMESTAMP_ATOMIC.load();

        if (timestamp == 0)
        {
            timestamp = time_stamp();
            TIMESTAMP_ATOMIC.store(timestamp);
        }

        for (unsigned int i = 0; i < THREAD_COUNT; i++)
        {
            std::thread thread(&session::hash_worker_handler, this, i, block_id, public_key, difficulty, timestamp);
            thread.detach();
        }
    }

    void handle_read(const boost::system::error_code &error,
                     size_t bytes_transferred)
    {
        if (!error)
        {
            std::string request;
            std::istream is(&read_data);
            std::getline(is, request);
            std::vector<std::string> items;

            boost::erase_all(request, "\n");
            boost::erase_all(request, "\r");

            boost::trim_if(request, DELIM);
            if (!request.empty())
            {
                boost::split(items, request, DELIM, boost::algorithm::token_compress_on);
            }

            if (items.size() > 0)
            {
                std::string command = items[0];

                if (command == WORK)
                {
                    std::cout << request << std::endl;
                    std::string block_id = items[1];
                    std::string public_key = items[2];
                    std::string difficulty = items[3];

                    hash_worker_stop();
                    hash_worker_start(block_id, public_key, difficulty);

                    write(std::string(SUCCESS).append(END_OF_STR));
                }
                else if (command == GET)
                {
                    if (best_difficulty != -1)
                    {
                        std::string body;
                        body.reserve(256);
                        body.append(GET);
                        body.append(",");
                        body.append(best_block_id);
                        body.append(",");
                        body.append(std::to_string(best_difficulty));
                        body.append(",");
                        body.append(best_nonce);
                        body.append(END_OF_STR);

                        write(body);
                    }
                    else
                    {
                        std::string body;
                        body.reserve(256);
                        body.append(GET);
                        body.append(",");
                        body.append(EMPTY);
                        body.append(",");
                        body.append(best_block_id);
                        body.append(END_OF_STR);

                        write(body);
                    }
                }
                else if (command == HASH)
                {
                    std::string block_id = items[1];
                    int digest_difficulty = std::stoi(items[2]);
                    std::string nonce = items[3];

                    if (best_block_id != block_id)
                    {
                        write(std::string(STOP).append(END_OF_STR));
                        return;
                    }

                    if (digest_difficulty >= best_difficulty)
                    {
                        best_nonce = nonce;
                        best_difficulty = digest_difficulty;
                    }

                    write(std::string(SUCCESS).append(END_OF_STR));
                }
                else if (command == CLOSE)
                {
                    std::string body(CLOSE);
                    boost::asio::write(socket_, boost::asio::buffer(body + END_OF_STR));
                    socket_.close();
                    unregister_session(this);
                    delete this;
                    return;
                }
                else if (command == STOP)
                {
                    hash_worker_stop();

                    write(std::string(SUCCESS).append(END_OF_STR));
                }
                else
                {
                    write(std::string(ERROR).append(END_OF_STR));
                }
            }
            else
            {
                write(std::string(ERROR).append(END_OF_STR));
            }
        }
        else
        {
            unregister_session(this);
            delete this;
        }
    }

    void handle_write(const boost::system::error_code &error)
    {
        if (!error)
        {
            read();
        }
        else
        {
            unregister_session(this);
            delete this;
        }
    }

    void read()
    {
        boost::asio::async_read_until(socket_, read_data, END_OF_STR,
                                      boost::bind(&session::handle_read, this,
                                                  boost::asio::placeholders::error,
                                                  boost::asio::placeholders::bytes_transferred));
    }

    void write(std::string &write_data)
    {
        boost::asio::async_write(socket_,
                                 boost::asio::buffer(write_data),
                                 boost::bind(&session::handle_write, this,
                                             boost::asio::placeholders::error));
    }

    tcp::socket socket_;
    boost::asio::streambuf read_data;
};

class server
{
public:
    server(boost::asio::io_service &io_service, short port)
        : io_service_(io_service),
          acceptor_(io_service, tcp::endpoint(boost::asio::ip::address::from_string(localAddress), port))
    {
        start_accept();
    }

private:
    void start_accept()
    {
        session *new_session = new session(io_service_);
        acceptor_.async_accept(new_session->socket(),
                               boost::bind(&server::handle_accept, this, new_session,
                                           boost::asio::placeholders::error));
    }

    void handle_accept(session *new_session,
                       const boost::system::error_code &error)
    {
        if (!error)
        {
            new_session->start();
            register_session(new_session);
        }
        else
        {
            unregister_session(new_session);
            delete new_session;
        }

        start_accept();
    }

    boost::asio::io_service &io_service_;
    tcp::acceptor acceptor_;
};

void handler(const boost::system::error_code& error,int signal_number)
{
    if (!error)
    {
        for (auto item : sessionList)
        {
            item->close();
        }
        exit(0);
    }
}

int main(int argc, char *argv[])
{
    try
    {
        if (argc != 2)
        {
            std::cerr << "Usage: hashServer <port>\n";
            return 1;
        }

        boost::asio::io_service io_service;
        boost::asio::signal_set signals(io_service, SIGINT, SIGTERM);
        signals.async_wait(handler);

        using namespace std; // For stoi.
        port = std::string(argv[1]);
        server s(io_service, stoi(port));

        io_service.run();
    }
    catch (std::exception &e)
    {
        std::cerr << "Exception: " << e.what() << "\n";
    }

    return 0;
}
