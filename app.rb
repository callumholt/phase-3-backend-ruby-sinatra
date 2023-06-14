require 'sinatra'
require 'rack/cors'
require 'json'
require 'bundler/setup'
require 'sinatra/activerecord'
require 'yaml'
require 'psych'

# the below 'before' piece of code is to help manage the CORS-POLICY issue
before do
    headers 'Access-Control-Allow-Origin' => '*',
            'Access-Control-Allow-Methods' => 'OPTIONS, GET, POST, PUT',
            'Access-Control-Allow-Headers' => 'Content-Type'
  end

use Rack::Cors do
  allow do
    origins '*' 
    resource '*', headers: [:any, :update], methods: [:get, :post, :options, :put, :delete],
      expose: ['access-token', 'expiry', 'token-type', 'uid', 'client'],
      max_age: 0
  end
end

set :database, { adapter: 'sqlite3', database: 'db.sqlite3' }

class Todo < ActiveRecord::Base
end

# the below was also necessary to help fix the cors-policy
options "*" do
  response.headers["Allow"] = "HEAD,GET,PUT,POST,DELETE,OPTIONS,UPDATE"

  response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"
  halt HTTP_STATUS_OK
end

# the below was the piece of ruby code to manage the POST request route that was sent to the /todo url
# it checks to see if the table already exists, and if it does not, it first creates the table using active record


post '/todo' do
    begin
    
    json_request_body = request.body.read
    content_type :json
  
    unless ActiveRecord::Base.connection.table_exists?(:todos)
      ActiveRecord::Base.connection.create_table :todos, id: false do |t|
        t.primary_key :id
        t.string :todo
        t.string :category
        t.string :user
      end
    end

# then it takes the json request and parses it, and sets a range of variables to the parsed data
# then it takes the variables and creates a new todo with the data

    request_body = JSON.parse(json_request_body)
    todo_value = request_body["todo"]
    category_value = request_body["category"]
    user_value = request_body["user"]  

    New_todo = Todo.create(todo: todo_value, category: category_value, user: user_value)
    if New_todo.valid?
        New_todo.to_json
    else
      halt 400, New_todo.errors.full_messages.join(', ')
    end

    rescue JSON::ParserError => e
    halt 400, "Invalid JSON data: #{e.message}"
    end

end

# this deals with the GET request for simply returning a specific todo

get '/todo/:user' do
    user = params[:user]
    todos = Todo.select(:id, :todo, :category).where(user: user)
    todos.to_json
  end

# the below is a PUT request that updates a specific todo

put '/todo/:id' do
    begin
    id = params[:id]
    request.body.rewind
    params = JSON.parse(request.body.read)
      todo = Todo.find(id)
  
      if todo.update(todo: params["todo"], category: params["category"], user: params["user"])
        todo.to_json
        # puts "Updated todo: #{todo.to_json}"

      else
        halt 400, todo.errors.full_messages.join(', ')
      end
  
    rescue ActiveRecord::RecordNotFound
      halt 404, "Todo not found with id #{id}"
    end
    content_type :json
  { message: "Todo updated successfully" }.to_json

  end
  
# the below is a DELETE request that destroys a specific todo based on the ID

delete '/todo/:id' do
    begin
      id = params[:id]
      todo = Todo.find(id)
      todo.destroy
      "Todo with id #{id} deleted"
  
    rescue ActiveRecord::RecordNotFound
      halt 404, "Todo not found with id #{id}"
    end
end
  
  
