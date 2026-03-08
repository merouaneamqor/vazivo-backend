# frozen_string_literal: true

# Shared examples for common API response patterns

RSpec.shared_examples "unauthorized request" do
  it "returns 401 unauthorized" do
    expect(response).to have_http_status(:unauthorized)
  end
end

RSpec.shared_examples "forbidden request" do
  it "returns 403 forbidden" do
    expect(response).to have_http_status(:forbidden)
  end
end

RSpec.shared_examples "not found request" do
  it "returns 404 not found" do
    expect(response).to have_http_status(:not_found)
  end
end

RSpec.shared_examples "successful request" do
  it "returns 200 OK" do
    expect(response).to have_http_status(:ok)
  end
end

RSpec.shared_examples "successful creation" do
  it "returns 201 created" do
    expect(response).to have_http_status(:created)
  end
end

RSpec.shared_examples "validation error" do
  it "returns 422 unprocessable entity" do
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "returns errors in response" do
    expect(json_response[:errors]).to be_present
  end
end

# Shared examples for paginated responses
RSpec.shared_examples "paginated response" do
  it "includes pagination meta" do
    expect(json_response[:meta]).to include(
      :current_page,
      :total_pages,
      :total_count,
      :per_page
    )
  end
end

# Shared examples for soft-deletable resources
RSpec.shared_examples "soft delete" do |resource_name|
  it "soft deletes the #{resource_name}" do
    expect(response).to have_http_status(:ok)
  end

  it "marks the record as discarded" do
    expect(subject.reload.discarded?).to be true
  end
end
