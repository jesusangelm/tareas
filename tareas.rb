require "rubygems"
require "sinatra"
require "sinatra/flash"
require "sinatra/redirect_with_flash"
Bundler.require

enable :sessions

SITE_TITLE = "LisTareas - Venezuela"
SITE_DESCRIPTION = "Has todas a tiempo y salva a un gatito!"

if ENV['VCAP_SERVICES'].nil?
  DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/dev.db")
else
  require 'json'
  svcs = JSON.parse ENV['VCAP_SERVICES']
  postgre = svcs.detect { |k,v| k =~ /^postgresql/ }.last.first
  creds = postgre['credentials']
  user, pass, host, name = %w(user password host name).map { |key| creds[key] }
  DataMapper.setup(:default, "postgres://#{user}:#{pass}@#{host}/#{name}")
end

class Note
  include DataMapper::Resource
  property :id, Serial
  property :content, Text, :required => true
  property :complete, Boolean, :required => true, :default => false
  property :created_at, DateTime
  property :updated_at, DateTime
end

DataMapper.finalize
Note.auto_upgrade!

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get "/" do
  @notes = Note.all :order => :id.desc
  @title = "Tareas"
  if @notes.empty?
    flash[:error] = "No se encontraron Tareas. Agrega una abajo."
  end
  erb :home
end

post "/" do
  n = Note.new
  n.content = params[:content]
  n.created_at = Time.now
  n.updated_at = Time.now
  if n.save
    redirect "/", :notice => "Tarea creada!"
  else
    redirect "/", :error => "Error al guardar la Tarea!"
  end
end

get "/rss.xml" do
  @notes = Note.all :order => :id.desc
  builder :rss
end

get "/:id" do
  @note = Note.get params[:id]
  @title = "Editar nota ##{params[:id]}"
  if @note
    erb :edit
  else
    redirect "/", "No se ha encontrado esta Tarea..."
  end
end

put "/:id" do
  n = Note.get params[:id]
  unless n 
    redirect "/", :error => "No se ha encontrado esta Tarea..."
  end
  n.content = params[:content]
  n.complete = params[:complete] ? 1 : 0
  n.updated_at = Time.now
  if n.save
    redirect "/", :notice => "Tarea actualizada!"
  else
    redirect "/", :error => "Error actualizando la Tarea..."
  end
end

get "/:id/delete" do
  @note = Note.get params[:id]
  @title = "Confirmar eliminacion de la nota ##{params[:id]}"
  if @note
    erb :delete
  else
    redirect "/", :error => "No se ha encontrado esta Tarea"
  end
end

delete "/:id" do
  n = Note.get params[:id]
  if n.destroy
    redirect "/", :notice => "Tarea Eliminada!"
  else
    redirect "/", :error => "Error eliminando la Tarea..."
  end
end

get "/:id/complete" do
  n = Note.get params[:id]
  unless n
    redirect "/", :error => "No se ha encontrado esta Tarea."
  end
  n.complete = n.complete ? 0 : 1
  n.updated_at = Time.now
  if n.save
    redirect "/", :notice => "Tarea marcada como Realizada!"
  else
    redirect "/", :error => "Error marcando la nota como Realizada..."
  end
end


