require "./spec_helper"
require "mongo"

describe Glassy::MongoODM::BSONDiff do
  it "makes diff" do
    bson1 = {
      "name" => "joseph",
      "age" => 5,
      "birth" => true,
      "brother" => {
        "name" => "rick",
        "type" => "a",
        "lastName" => "morty"
      },
      "listOne" => ["a", "b"],
      "listTwo" => ["a", "b", "c"],
      "listThree" => [
        {
          "name" => "David"
        },
        {
          "name" => "Xin Zhao"
        }
      ]
    }.to_bson

    bson2 = {
      "name" => "joseph",
      "age" => 3,
      "parent" => {
        "name" => "john"
      },
      "brother" => {
        "name" => "rick",
        "type" => "b"
      },
      "listOne" => ["a", "b", "c"],
      "listTwo" => ["a", "b"],
      "listThree" => [
        {
          "name" => "David"
        },
        {
          "name" => "Yasuo"
        }
      ]
    }.to_bson

    diff = Glassy::MongoODM::BSONDiff.new.diff(bson1, bson2)

    diff.should eq ({
      "$set" => {
        "age" => 3,
        "parent" => {
          "name" => "john"
        },
        "brother.type" => "b",
        "listOne" => ["a", "b", "c"],
        "listTwo" => ["a", "b"],
        "listThree.1.name" => "Yasuo"
      },
      "$unset" => {
        "birth" => "",
        "brother.lastName" => ""
      }
    }).to_bson
  end
end
