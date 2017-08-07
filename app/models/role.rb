require "credentials"
require "menu"

class Role < ActiveRecord::Base
  belongs_to :parent, class_name: 'Role'
  has_many :users

  serialize :cache
  validates :name, presence: true
  validates :name, uniqueness: true

  attr_accessor :cache
  attr_reader :student, :ta, :instructor, :administrator, :superadministrator

  def cache
    @cache = {}
    unless self.nil?
      @cache[:credentials] = CACHED_ROLES[self.id][:credentials]
      @cache[:menu] = CACHED_ROLES[self.id][:menu]
    end
    @cache
  end

  def self.find_or_create_by_name(params)
    Role.find_or_create_by(name: params)
  end

  def self.student
    @@student_role ||= find_by_name 'Student'
  end

  def student?
    name['Student']
  end

  def instructor?
    name['Instructor']
  end

  def ta?
    name['Teaching Assistant']
  end

  def admin?
    name['Administrator'] || super_admin?
  end

  def self.ta
    @@ta_role ||= find_by_name 'Teaching Assistant'
  end

  def self.instructor
    @@instructor_role ||= find_by_name 'Instructor'
  end

  def self.administrator
    @@administrator_role ||= find_by_name 'Administrator'
  end

  def self.admin
    administrator
  end

  def self.superadministrator
    @@superadministrator_role ||= find_by_name 'Super-Administrator'
  end

  def super_admin?
    name['Super-Administrator']
  end

  def self.super_admin
    superadministrator
  end

  def self.rebuild_cache
    Role.find_each do |role|
      role.cache = {}
      role.rebuild_credentials
      role.rebuild_menu
    end
  end

  def other_roles
    if !id.is_a? Integer
      flash[:error] = "Illegal parameter."
    else
      Role.where('id != ?', id).order(:name)
    end
  end

  def rebuild_credentials
    self.cache[:credentials] = CACHED_ROLES[self.id][:credentials]
  end

  def rebuild_menu
    self.cache[:menu] = CACHED_ROLES[self.id][:menu]
  end

  # return ids of roles that are below this role
  def get_available_roles
    ids = []

    current = self.parent_id
    while current
      role = Role.find(current)
      next unless role
      unless ids.index(role.id)
        ids << role.id
        current = role.parent_id
      end
    end
    ids
  end

  # "parents" are lesser roles. This returns a list including this role and all lesser roels.
  def get_parents
    parents = []
    seen = {}

    current = self.id

    while current
      role = Role.find(current)
      if role
        if !seen.key?(role.id)
          parents << role
          seen[role.id] = true
          current = role.parent_id
        else
          current = nil
        end
      else
        current = nil
      end
    end

    parents
  end

  # determine if the current role has all the privileges of the parameter role
  def hasAllPrivilegesOf(target_role)
    privileges = {}
    privileges["Student"] = 1
    privileges["Teaching Assistant"] = 2
    privileges["Instructor"] = 3
    privileges["Administrator"] = 4
    privileges["Super-Administrator"] = 5

    privileges[self.name] > privileges[target_role.name]
  end

  def update_with_params(role_params)
    begin
      self.name = role_params[:name]
      self.parent_id = role_params[:parent_id]
      self.description = role_params[:description]
      self.save
    rescue StandardError => e
      false
    end
  end
end
